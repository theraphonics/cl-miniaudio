(ql:quickload :cffi)
(ql:quickload :cffi-grovel)

(defpackage :miniaudio
  (:use :common-lisp :cffi :cffi-grovel))

(in-package :miniaudio)

(cffi:define-foreign-library libminiaudio
  (:unix (:default "libminiaudio.so")
   :darwin (:default "libminiaudio.dylib")
   :windows (:default "miniaudio.dll")))

(cffi:defcfun "ma_context_init" :int
  (ma_context :pointer))

;; Define your C structs and functions here

(cffi:use-foreign-library libminiaudio)


;;; Constants
(defconstant MA_SUCCESS 0)
(defconstant MA_LOG_LEVEL_INFO 2)
(defconstant MA_LOG_LEVEL_WARNING 3)
(defconstant MA_LOG_LEVEL_ERROR 4)

(defconstant MA_FORMAT_S16 #x1)
(defconstant MA_FORMAT_F32 #x2)

(defconstant MA_SHARE_MODE_SHARED 0)
(defconstant MA_SHARE_MODE_EXCLUSIVE 1)

(defconstant MA_DEVICE_TYPE_PLAYBACK 1)
(defconstant MA_DEVICE_TYPE_CAPTURE 2)

;;; Structs
(cffi:defcstruct ma_context
  (backend :int)
  (p_backend :pointer)
  (log_callback :pointer)
  (log_userdata :pointer))

(cffi:defcstruct ma_device_info
  (name :pointer)
  (id :int)
  (output_format :int)
  (input_format :int)
  (min_buffer_size_in_frames :int)
  (max_buffer_size_in_frames :int)
  (buffer_size_in_frames :int)
  (performance_profile :int)
  (share_mode :int)
  (type :int))

(cffi:defcstruct ma_device_config
  (capture_format :int)
  (capture_channels :int)
  (sample_rate :int)
  (data_callback :pointer)
  (p_userdata :pointer)
  (playback_format :int)
  (playback_channels :int)
  (no_pre_zero :int)
  (no_clip :int)
  (no_dither :int)
  (no_peak_filter :int)
  (no_linear_resampler :int))

(cffi:defcstruct ma_device
  (type :int)
  (state :int)
  (playback :pointer)
  (capture :pointer)
  (capture_channels :int)
  (playback_channels :int)
  (p_userdata :pointer)
  (on_stop_callback :pointer)
  (log_callback :pointer))

;;; Functions
(define-foreign-library libminiaudio
  (:default "miniaudio"))

(use-foreign-library libminiaudio)

(defcfun ("ma_context_init" context-init) :int
  (backend :int)
  (p_backend :pointer))

(defcfun ("ma_context_uninit" context-uninit) :void
  (p_context :pointer))

(defcfun ("ma_context_set_log_callback" context-set-log-callback) :void
  (p_context :pointer)
  (log_callback :pointer)
  (p_user_data :pointer))

(defcfun ("ma_context_get_device_count" context-get-device-count) :int
  (p_context :pointer))

(defcfun ("ma_context_get_device_info" context-get-device-info) :int
  (p_context :pointer)
  (device_type :int)
  (p_info :pointer)
  (index :int))

(defcfun ("ma_context_get_default_device_info" context-get-default-device-info) :int
  (p_context :pointer)
  (device_type :int)
  (p_info :pointer))

(defcfun ("ma_device_init" device-init) :int
  (p_context :pointer)
  (p_config :pointer)
  (p_device :pointer))

(defcfun ("ma_device_uninit" device-uninit) :void
  (p_device :pointer))

(defcfun ("ma_device_start" device-start) :int
  (p_device :pointer))

(defcfun ("ma_device_stop" device-stop) :int
  (p_device :pointer))

(defcfun ("ma_device_is_started" device-is-started) :int
  (p_device :pointer))

(defcfun ("ma_device_set_volume" device-set-volume) :int
  (p_device :pointer)
  (volume :float))

(defcfun ("ma_device_set_master_volume" device-set-master-volume) :int
  (p_device :pointer)
  (volume :float))

(defcfun ("ma_device_set_paused" device-set-paused) :int
  (p_device :pointer)
  (paused :int))

(defcfun ("ma_device_get_data_format" device-get-data-format) :int
  (p_device :pointer))

(defcfun ("ma_device_get_channels" device-get-channels) :int
  (p_device :pointer))

(defcfun ("ma_device_get_sample_rate" device-get-sample-rate) :int
  (p_device :pointer))

(defcfun ("ma_device_get_buffer_size_in_frames" device-get-buffer-size-in-frames) :int
  (p_device :pointer))

(defcfun ("ma_device_get_current_latency_in_frames" device-get-current-latency-in-frames) :int
  (p_device :pointer))

(defcfun ("ma_device_get_time_since_start" device-get-time-since-start) :float
  (p_device :pointer))

(defcfun ("ma_device_get_time_to_next_render" device-get-time-to-next-render) :float
  (p_device :pointer))

(defcfun ("ma_device_get_time_to_next_fill" device-get-time-to-next-fill) :float
  (p_device :pointer))

(defcfun ("ma_device_get_remaining_frames" device-get-remaining-frames) :int
  (p_device :pointer))

(defcfun ("ma_waveform_sin_i16" waveform-sin-i16)
  :void
  (pSamples :pointer)
  (frameCount :int)
  (sampleRate :int)
  (amplitude :float))

(defun ma-device-callback-handler (pDevice pOutput pInput frameCount)
  (let ((output-buffer (foreign-array :signed-short :dimensions (list frameCount)))
        (input-buffer (foreign-array :signed-short :dimensions (list frameCount))))
    (funcall (foreign-value (ma-device-config-data-callback (slot-value (deref pDevice) 'ma-device-config)))
             (foreign-pointer output-buffer)
             (foreign-pointer input-buffer)
             frameCount
             (ma-device-get-sample-rate pDevice)
             (ma-device-get-channels pDevice)
             (ma_device_type_playback)))
  (foreign-array-to-c-array pOutput output-buffer)
  (foreign-array-to-c-array pInput input-buffer)
  ma-success)

(defparameter *context* nil)
(defparameter *device* nil)

(defun ma-device-start ()
  (setf *context* (context-init 0 nil))
  (let* ((device-info (make-ma-device-info))
         (device-config (make-ma-device-config))
         (p-device-info (foreign-alloc :pointer))
         (p-device-config (foreign-alloc :pointer)))
    (setf (ma-device-info-share-mode device-info) ma-share-mode_shared)
    (setf (ma-device-info-type device-info) ma_device_type_playback)
    (setf (ma-device-config-sample-rate device-config) 44100)
    (setf (ma-device-config-data-callback device-config) 'ma-device-callback-handler)
    (setf (ma-device-config-user-data device-config) nil)
    (setf (ma-device-config-performance-profile device-config) ma_performance_profile_low_latency)
    (setf (ma_device_id p-device-info) 0)
    (setf (ma_device_init p_context p-device-info device-config p-device) ma_success)
    (when (= ma_success (ma_device_start p-device))
      (format t "Playback started.~%"))
    (when (= ma_device_type_capture (ma-device-info-type device-info))
      (format t "Recording started.~%")))
  t)

(defun ma-device-stop ()
  (when *device*
    (ma_device_stop *device*)
    (ma_device_uninit *device*)
    (setf *device* nil)
    (setf *context* nil))
  t)

(defun ma-device-is-started ()
  (if *device*
      (= (ma_device_is_started *device*) ma_true)
      nil))

(defun ma-device-set-volume (volume)
  (when *device*
    (ma_device_set_volume *device* volume))
  t)

(defun ma-device-set-master-volume (volume)
  (when *device*
    (ma_device_set_master_volume *device* volume))
  t)

(defun ma-device-set-paused (paused)
  (when *device*
    (ma_device_set_paused *device* paused))
  t)

(defun ma-device-get-data-format ()
  (when *device*
    (ma_device_get_data_format *device*)))

(defun ma-device-get-channels ()
  (when *device*
    (ma_device_get_channels *device*)))

(defun ma-device-get-sample-rate ()
  (when *device*
    (ma_device_get_sample_rate *device*)))

(defun ma-device-get-buffer-size-in-frames ()
  (when *device*
    (ma_device_get_buffer_size_in_frames *device*)))

(defun ma-device-get-current-latency-in-frames ()
  (when *device*
    (ma_device_get_current_latency_in_frames *device*)))

(defun ma-device-get-time-since-start ()
  (when *device*
    (ma_device_get_time_since_start *device*)))

(defun ma-device-get-time-to-next-render ()
  (when *device*
    (ma_device_get_time_to_next_render *device*)))

(defun ma-device-get-time-to-next-fill ()
  (when *device*
    (ma_device_get_time_to_next_fill *device*)))

(defun ma-device-get-remaining-frames ()
  (when *device*
      (ma_device_get_remaining_frames *device*)))
