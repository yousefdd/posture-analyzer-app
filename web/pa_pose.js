// Posture Analyzer: camera, video file and pose bridge for the web / desktop build.
//
// The phone app uses the camera plugin and ML Kit. In a browser this file opens
// the webcam (or a video file), runs MediaPipe Pose Landmarker (bundled under
// mediapipe/, Apache-2.0) and hands the 33 body points to Dart:
//   [[x, y, visibility] x 33], x and y in 0..1 of the frame.
// It can also record the camera session to a WebM file. Nothing leaves the browser.
(function () {
  const S = {
    video: null, stream: null, live: null, image: null, still: null,
    latest: null, running: false, error: null, mirror: true,
    recorder: null, chunks: [], fileVideo: null, canvas: null,
    small: null, busyUntil: 0, cost: 30,
  };

  // The model looks at a 256-pixel image, so a small copy of each frame is
  // enough, and much cheaper than the full camera picture.
  const DETECT_WIDTH = 320;

  function shrink(v) {
    const c = S.small || (S.small = document.createElement('canvas'));
    const w = DETECT_WIDTH, h = Math.max(1, Math.round((v.videoHeight / v.videoWidth) * DETECT_WIDTH));
    if (c.width !== w) c.width = w;
    if (c.height !== h) c.height = h;
    c.getContext('2d', { willReadFrequently: false }).drawImage(v, 0, 0, w, h);
    return c;
  }

  function cameraVideo() {
    if (!S.video) {
      const v = document.createElement('video');
      v.autoplay = true;
      v.muted = true;
      v.playsInline = true;
      v.setAttribute('playsinline', '');
      v.style.cssText = 'width:100%;height:100%;object-fit:cover;background:#000;';
      S.video = v;
    }
    S.video.style.transform = S.mirror ? 'scaleX(-1)' : 'none';
    return S.video;
  }

  async function create(mode, delegate) {
    const base = new URL('mediapipe/', document.baseURI).href;
    const vision = await import(base + 'vision_bundle.mjs');
    const fileset = await vision.FilesetResolver.forVisionTasks(base + 'wasm');
    return vision.PoseLandmarker.createFromOptions(fileset, {
      baseOptions: { modelAssetPath: base + 'pose_landmarker_lite.task', delegate },
      runningMode: mode,
      numPoses: 1,
    });
  }

  // The graphics card is fastest on a good one, but on a weak or unsupported
  // one the browser emulates it and it is many times slower than the
  // processor. The live camera tries both on its first frames and keeps the
  // faster; a video file uses the processor, which is fast and dependable.
  async function landmarker(mode) {
    const key = mode === 'IMAGE' ? 'image' : 'live';
    if (S[key]) return S[key];
    if (mode === 'IMAGE') {
      S[key] = await create(mode, 'CPU');
      return S[key];
    }
    S.cpu = await create(mode, 'CPU');
    try {
      S.gpu = await create(mode, 'GPU');
    } catch (_) {
      S.gpu = null;
    }
    S.trial = { gpu: [], cpu: [] };
    S[key] = S.gpu || S.cpu;
    if (!S.gpu) S.trial = null;
    return S[key];
  }

  // Each trial detection's time; after six on each, the faster one stays.
  function judge(spent) {
    const t = S.trial;
    if (!t) return;
    const which = S.live === S.gpu ? 'gpu' : 'cpu';
    t[which].push(spent);
    // An emulated card is obvious at once (hundreds of ms): stop trying it.
    if (which === 'gpu' && t.gpu.length >= 2 && spent > 150) {
      t.gpu = Array(6).fill(Infinity);
      S.live = S.cpu;
      return;
    }
    if (which === 'gpu' && t.gpu.length >= 6) S.live = S.cpu;
    if (t.gpu.length >= 6 && t.cpu.length >= 6) {
      const mid = (a) => a.slice(1).sort((x, y) => x - y)[Math.floor((a.length - 1) / 2)];
      const keep = mid(t.gpu) <= mid(t.cpu) ? 'gpu' : 'cpu';
      S.live = keep === 'gpu' ? S.gpu : S.cpu;
      const drop = keep === 'gpu' ? S.cpu : S.gpu;
      try { drop.close(); } catch (_) {}
      S.gpu = S.cpu = null;
      S.trial = null;
      S.delegate = keep;
      S.cost = mid(keep === 'gpu' ? t.gpu : t.cpu);
    }
  }

  function points(pose, mirror) {
    return pose.map((p) => [mirror ? 1 - p.x : p.x, p.y, p.visibility == null ? 1 : p.visibility]);
  }

  function loop() {
    if (!S.running) return;
    const v = S.video;
    const now = performance.now();
    // Detection runs on the page's own thread, so it leaves the page as much
    // time again to draw between runs: smooth on slow computers, and as often
    // as the camera allows on fast ones.
    if (v && v.readyState >= 2 && S.live && v.videoWidth && now >= S.busyUntil) {
      try {
        const r = S.live.detectForVideo(shrink(v), now);
        const pose = r && r.landmarks && r.landmarks[0];
        S.latest = { t: now / 1000, w: v.videoWidth, h: v.videoHeight, lm: pose ? points(pose, S.mirror) : [] };
      } catch (e) {
        S.error = String(e);
      }
      const spent = performance.now() - now;
      if (S.trial) judge(spent);
      else S.cost = 0.8 * S.cost + 0.2 * spent;
      S.busyUntil = performance.now() + Math.max(1.2 * S.cost, 20);
    }
    if (v && 'requestVideoFrameCallback' in v) v.requestVideoFrameCallback(loop);
    else requestAnimationFrame(loop);
  }

  window.paPose = {
    video: cameraVideo,

    // Opens the webcam and the model; true once both run.
    start: async function (mirror, front) {
      if (S.running) return true;
      S.mirror = !!mirror;
      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) throw new Error('no camera API');
        S.stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: front ? 'user' : 'environment', width: { ideal: 960 }, height: { ideal: 540 } },
          audio: false,
        });
        const v = cameraVideo();
        v.srcObject = S.stream;
        await v.play().catch(() => {});
        await landmarker('VIDEO');
        S.running = true;
        loop();
        return true;
      } catch (e) {
        S.error = String(e);
        window.paPose.stop();
        return false;
      }
    },

    // Opens the webcam once and closes it: is there a camera we may use?
    check: async function () {
      try {
        const s = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
        s.getTracks().forEach((t) => t.stop());
        return true;
      } catch (_) {
        return false;
      }
    },

    pause: function () {
      S.running = false;
      if (S.recorder && S.recorder.state === 'recording') S.recorder.pause();
    },
    resume: function () {
      if (S.recorder && S.recorder.state === 'paused') S.recorder.resume();
      if (!S.running && S.stream) {
        S.running = true;
        loop();
      }
    },

    stop: function () {
      S.running = false;
      if (S.video) S.video.pause();
      if (S.stream) S.stream.getTracks().forEach((t) => t.stop());
      S.stream = null;
      S.latest = null;
    },

    frame: function () {
      return S.latest;
    },
    error: function () {
      return S.error;
    },
    // Milliseconds one detection takes, smoothed, and on what.
    cost: function () {
      return S.cost;
    },
    delegate: function () {
      return S.delegate || (S.trial ? 'trying' : '');
    },

    // Records the camera to WebM while the session runs.
    record: function () {
      if (!S.stream || typeof MediaRecorder === 'undefined') return false;
      try {
        const type = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find((t) => MediaRecorder.isTypeSupported(t));
        S.chunks = [];
        S.recorder = new MediaRecorder(S.stream, type ? { mimeType: type } : undefined);
        S.recorder.ondataavailable = (e) => e.data && e.data.size && S.chunks.push(e.data);
        S.recorder.start(1000);
        return true;
      } catch (e) {
        S.error = String(e);
        S.recorder = null;
        return false;
      }
    },

    // Ends the recording and downloads it; resolves true if a file was saved.
    saveRecording: function (name) {
      return new Promise((resolve) => {
        const r = S.recorder;
        if (!r) return resolve(false);
        r.onstop = () => {
          S.recorder = null;
          if (!S.chunks.length) return resolve(false);
          const url = URL.createObjectURL(new Blob(S.chunks, { type: 'video/webm' }));
          const a = document.createElement('a');
          a.href = url;
          a.download = name;
          document.body.appendChild(a);
          a.click();
          a.remove();
          setTimeout(() => URL.revokeObjectURL(url), 60000);
          resolve(true);
        };
        try {
          r.stop();
        } catch (_) {
          resolve(false);
        }
      });
    },

    // A video file: open it, then analyse one moment at a time.
    openFile: function (url) {
      return new Promise((resolve) => {
        const v = document.createElement('video');
        v.muted = true;
        v.preload = 'auto';
        v.playsInline = true;
        v.src = url;
        v.onloadedmetadata = () => {
          S.fileVideo = v;
          resolve(isFinite(v.duration) ? v.duration : 0);
        };
        v.onerror = () => resolve(-1);
      });
    },

    // Seeks to [t] seconds, finds the pose, and returns the frame as a JPEG
    // data URL with the points: {w, h, lm, jpeg}.
    analyseAt: async function (t) {
      const v = S.fileVideo;
      if (!v) return null;
      await new Promise((resolve) => {
        const done = () => {
          v.removeEventListener('seeked', done);
          resolve();
        };
        v.addEventListener('seeked', done);
        v.currentTime = Math.min(t, Math.max(0, v.duration - 0.05));
      });
      const lm = await landmarker('IMAGE');
      const w = v.videoWidth, h = v.videoHeight;
      const scale = Math.min(1, 640 / w);
      const c = S.canvas || (S.canvas = document.createElement('canvas'));
      c.width = Math.round(w * scale);
      c.height = Math.round(h * scale);
      c.getContext('2d').drawImage(v, 0, 0, c.width, c.height);
      let pose = null;
      try {
        const r = lm.detect(c);
        pose = r && r.landmarks && r.landmarks[0];
      } catch (e) {
        S.error = String(e);
      }
      return { w: c.width, h: c.height, lm: pose ? points(pose, false) : [], jpeg: c.toDataURL('image/jpeg', 0.8) };
    },

    closeFile: function () {
      if (S.fileVideo) {
        S.fileVideo.removeAttribute('src');
        S.fileVideo.load();
      }
      S.fileVideo = null;
    },
  };
})();
