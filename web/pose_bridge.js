// MediaPipe Pose JS bridge for Flutter web.
// Loads the MediaPipe Pose Landmarker and exposes detectPose() for Dart interop.

const poseBridge = {
  _landmarker: null,
  _ready: false,
  _initializing: false,

  isReady() {
    return this._ready;
  },

  async init() {
    if (this._ready || this._initializing) return;
    this._initializing = true;

    try {
      const { PoseLandmarker, FilesetResolver } = await import(
        "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/vision_bundle.mjs"
      );

      const vision = await FilesetResolver.forVisionTasks(
        "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/wasm"
      );

      this._landmarker = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath:
            "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task",
          delegate: "GPU",
        },
        runningMode: "VIDEO",
        numPoses: 5,
      });

      this._ready = true;
      console.log("MediaPipe Pose Landmarker initialized");
    } catch (e) {
      console.error("Failed to initialize MediaPipe Pose:", e);
      this._initializing = false;
    }
  },

  /**
   * Detect pose landmarks from an HTMLVideoElement.
   * Returns an array of 33 {x, y, z, visibility} objects, or null.
   */
  detectPose(videoElement) {
    if (!this._ready || !this._landmarker) return null;
    if (videoElement.readyState < 2) return null; // HAVE_CURRENT_DATA

    try {
      const result = this._landmarker.detectForVideo(
        videoElement,
        performance.now()
      );

      if (
        !result ||
        !result.landmarks ||
        result.landmarks.length === 0 ||
        result.landmarks[0].length < 33
      ) {
        return null;
      }

      // Return the 33 landmarks (already normalized 0-1 by MediaPipe).
      return result.landmarks[0].map((lm) => ({
        x: lm.x,
        y: lm.y,
        z: lm.z,
        visibility: lm.visibility ?? 0.0,
      }));
    } catch (e) {
      console.error("Pose detection error:", e);
      return null;
    }
  },

  /**
   * Detect pose at a specific timestamp (for uploaded video processing).
   * Uses caller-supplied timestampMs instead of performance.now().
   */
  detectPoseAtTime(videoElement, timestampMs) {
    if (!this._ready || !this._landmarker) return null;
    if (videoElement.readyState < 2) return null;

    try {
      const result = this._landmarker.detectForVideo(
        videoElement,
        timestampMs
      );

      if (
        !result ||
        !result.landmarks ||
        result.landmarks.length === 0 ||
        result.landmarks[0].length < 33
      ) {
        return null;
      }

      return result.landmarks[0].map((lm) => ({
        x: lm.x,
        y: lm.y,
        z: lm.z,
        visibility: lm.visibility ?? 0.0,
      }));
    } catch (e) {
      console.error("Pose detection (at time) error:", e);
      return null;
    }
  },

  /**
   * Detect poses for ALL persons in the frame.
   * Returns an array of arrays: [[33 lm], [33 lm], ...], or null.
   */
  detectMultiPose(videoElement) {
    if (!this._ready || !this._landmarker) return null;
    if (videoElement.readyState < 2) return null;

    try {
      const result = this._landmarker.detectForVideo(
        videoElement,
        performance.now()
      );

      if (!result || !result.landmarks || result.landmarks.length === 0) {
        return null;
      }

      return result.landmarks.map((personLandmarks) =>
        personLandmarks.map((lm) => ({
          x: lm.x,
          y: lm.y,
          z: lm.z,
          visibility: lm.visibility ?? 0.0,
        }))
      );
    } catch (e) {
      console.error("Multi-pose detection error:", e);
      return null;
    }
  },

  /**
   * Detect poses for ALL persons at a specific timestamp.
   * Returns an array of arrays: [[33 lm], [33 lm], ...], or null.
   */
  detectMultiPoseAtTime(videoElement, timestampMs) {
    if (!this._ready || !this._landmarker) return null;
    if (videoElement.readyState < 2) return null;

    try {
      const result = this._landmarker.detectForVideo(
        videoElement,
        timestampMs
      );

      if (!result || !result.landmarks || result.landmarks.length === 0) {
        return null;
      }

      return result.landmarks.map((personLandmarks) =>
        personLandmarks.map((lm) => ({
          x: lm.x,
          y: lm.y,
          z: lm.z,
          visibility: lm.visibility ?? 0.0,
        }))
      );
    } catch (e) {
      console.error("Multi-pose detection (at time) error:", e);
      return null;
    }
  },
};

// Auto-initialize on load.
poseBridge.init();

// Expose globally for Dart JS interop.
window.poseBridge = poseBridge;
