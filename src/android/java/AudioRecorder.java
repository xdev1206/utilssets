package com.example.audio

import android.annotation.SuppressLint;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public class AudioRecorder {
    private static final String TAG = "AudioRecorder";

    // 音频配置参数
    private static final int SAMPLE_RATE = 16000; // 采样率
    private static final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO; // 单声道
    private static final int ENCODING_FORMAT = AudioFormat.ENCODING_PCM_16BIT; // 16位PCM编码

    // 录制状态
    private final AtomicBoolean isRecording = new AtomicBoolean(false);
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);

    // 音频录制相关
    private AudioRecord audioRecord;
    private int bufferSize;
    private byte[] audioBuffer;

    // 线程管理
    private ExecutorService audioThread;
    private ExecutorService recordingThread;

    // 监听器管理
    private final List<RecorderListener> listeners = new ArrayList<>();
    private final Object listenerLock = new Object();
    
    public interface RecorderListener {
        void onAudioBuffer(byte[] data, int dataSize);
    }
    
    public AudioRecorder(int audioSource) {
        audioThread = Executors.newSingleThreadExecutor(r -> {
            Thread thread = new Thread(r, "AudioRecorder-Control");
            thread.setDaemon(true);
            return thread;
        });

        recordingThread = Executors.newSingleThreadExecutor(r -> {
            Thread thread = new Thread(r, "AudioRecorder-Recording");
            thread.setDaemon(true);
            return thread;
        });
    }
    
    public synchronized void startRecord() {
        if (isRecording.get()) {
            Log.w(TAG, "Recording is already started");
            return;
        }

        audioThread.execute(() -> {
            try {
                if (!isInitialized.get()) {
                    initAudioRecord();
                }

                if (audioRecord != null && audioRecord.getState() == AudioRecord.STATE_INITIALIZED) {
                    audioRecord.startRecording();
                    isRecording.set(true);

                    // 启动录制线程
                    startRecordingThread();

                    Log.i(TAG, "Audio recording started successfully");
                } else {
                    Log.e(TAG, "Failed to start recording: AudioRecord not properly initialized");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error starting audio recording", e);
                isRecording.set(false);
            }
        });
    }
    
    public synchronized void stopRecord() {
        if (!isRecording.get()) {
            Log.w(TAG, "Recording is not started");
            return;
        }

        audioThread.execute(() -> {
            try {
                isRecording.set(false);

                if (audioRecord != null) {
                    if (audioRecord.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) {
                        audioRecord.stop();
                    }
                    Log.i(TAG, "Audio recording stopped successfully");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error stopping audio recording", e);
            }
        });
    }

    /**
     * 注册监听器
     */
    public void registerListener(RecorderListener cb) {
        if (cb == null) {
            Log.w(TAG, "Trying to register null listener");
            return;
        }

        synchronized (listenerLock) {
            if (!listeners.contains(cb)) {
                listeners.add(cb);
                Log.d(TAG, "Listener registered, total listeners: " + listeners.size());
            }
        }
    }

    /**
     * 注销监听器
     */
    public void unregisterListener(RecorderListener cb) {
        if (cb == null) {
            Log.w(TAG, "Trying to unregister null listener");
            return;
        }

        synchronized (listenerLock) {
            if (listeners.remove(cb)) {
                Log.d(TAG, "Listener unregistered, total listeners: " + listeners.size());
            }
        }
    }

    @SuppressLint("MissingPermission")
    private void initAudioRecord() {
        try {
            // 计算缓冲区大小
            bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, ENCODING_FORMAT);
            if (bufferSize == AudioRecord.ERROR_BAD_VALUE || bufferSize == AudioRecord.ERROR) {
                Log.e(TAG, "Invalid buffer size: " + bufferSize);
                return;
            }

            audioBuffer = new byte[bufferSize];

            // 创建AudioRecord实例
            audioRecord = new AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    ENCODING_FORMAT,
                    bufferSize * 2
            );

            if (audioRecord.getState() == AudioRecord.STATE_INITIALIZED) {
                isInitialized.set(true);
                Log.i(TAG, "AudioRecord initialized successfully, buffer size: " + bufferSize);
            } else {
                Log.e(TAG, "AudioRecord initialization failed");
                releaseAudioRecord();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error initializing AudioRecord", e);
            releaseAudioRecord();
        }
    }

    private void startRecordingThread() {
        recordingThread.execute(() -> {
            Log.d(TAG, "Recording thread started");

            while (isRecording.get() && audioRecord != null) {
                try {
                    int bytesRead = audioRecord.read(audioBuffer, 0, bufferSize);

                    if (bytesRead > 0) {
                        // 通知所有监听器
                        notifyListeners(audioBuffer, bytesRead);
                    } else if (bytesRead == AudioRecord.ERROR_INVALID_OPERATION) {
                        Log.e(TAG, "AudioRecord read error: ERROR_INVALID_OPERATION");
                        break;
                    } else if (bytesRead == AudioRecord.ERROR_BAD_VALUE) {
                        Log.e(TAG, "AudioRecord read error: ERROR_BAD_VALUE");
                        break;
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error reading audio data", e);
                    break;
                }
            }

            Log.d(TAG, "Recording thread stopped");
        });
    }

    private void notifyListeners(byte[] data, int dataSize) {
        synchronized (listenerLock) {
            if (!listeners.isEmpty()) {
                // 创建数据副本以避免并发修改
                byte[] dataCopy = new byte[dataSize];
                System.arraycopy(data, 0, dataCopy, 0, dataSize);

                for (RecorderListener listener : listeners) {
                    try {
                        listener.onAudioBuffer(dataCopy, dataSize);
                    } catch (Exception e) {
                        Log.e(TAG, "Error notifying listener", e);
                    }
                }
            }
        }
    }

    private void releaseAudioRecord() {
        audioThread.execute(() -> {
            try {
                if (audioRecord != null) {
                    if (audioRecord.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) {
                        audioRecord.stop();
                    }
                    audioRecord.release();
                    audioRecord = null;
                    Log.i(TAG, "AudioRecord released");
                }
                isInitialized.set(false);
                isRecording.set(false);
            } catch (Exception e) {
                Log.e(TAG, "Error releasing AudioRecord", e);
            }
        });
    }

    /**
     * 销毁录制器，释放所有资源
     */
    public void destroy() {
        Log.i(TAG, "Destroying AudioRecorder");

        // 停止录制
        stopRecord();

        // 清空监听器
        synchronized (listenerLock) {
            listeners.clear();
        }

        // 释放AudioRecord
        releaseAudioRecord();

        // 关闭线程池
        if (audioThread != null && !audioThread.isShutdown()) {
            audioThread.shutdown();
            audioThread = null;
        }
        if (recordingThread != null && !recordingThread.isShutdown()) {
            recordingThread.shutdown();
            recordingThread = null;
        }

        Log.i(TAG, "AudioRecorder destroyed");
    }

    public boolean isRecording() {
        return isRecording.get();
    }

    public boolean isInitialized() {
        return isInitialized.get();
    }
}
