package com.example.audio

import android.annotation.SuppressLint;
import android.content.Context;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.util.Log;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

public class AudioRecorder {
    private static final String TAG = "AudioRecorder";

    // 音频配置参数
    private static final int SAMPLE_RATE = 16000; // 采样率
    private static final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO; // 单声道
    private static final int AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT; // 16位PCM
    private static final int AUDIO_SOURCE = MediaRecorder.AudioSource.MIC; // 麦克风

    // 录音相关
    private AudioRecord audioRecord;
    private int bufferSize;
    private final AtomicBoolean isRecording = new AtomicBoolean(false);
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private byte[] audioBuffer;
    private int audioSource = MediaRecorder.AudioSource.VOICE_RECOGNITION;

    // 线程相关
    private Thread audioThread;
    private Thread recordThread;
    private final Object threadLock = new Object();

    // 监听器列表
    private final List<RecorderListener> listeners = new ArrayList<>();

    public interface RecorderListener {
        void onAudioBuffer(byte[] data, int volume);
    }

    public AudioRecorder(int audioSource) {
        this.audioSource = audioSource;
        initAudioRecord();
    }

    @SuppressLint("MissingPermission")
    private void initAudioRecord() {
        audioThread = new Thread(() -> {
            try {
                Log.d(TAG, "create new AudioRecord instance");

                // 获取最小缓冲区大小
                bufferSize = AudioRecord.getMinBufferSize(
                        SAMPLE_RATE,
                        CHANNEL_CONFIG,
                        AUDIO_FORMAT
                );

                if (bufferSize == AudioRecord.ERROR_BAD_VALUE || bufferSize == AudioRecord.ERROR) {
                    Log.e(TAG, "can't get valid min buffer size");
                    return;
                }

                // 创建AudioRecord实例
                audioRecord = new AudioRecord(
                        AUDIO_SOURCE,
                        SAMPLE_RATE,
                        CHANNEL_CONFIG,
                        AUDIO_FORMAT,
                        bufferSize * 2 // 使用2倍缓冲区大小
                );

                // 检查AudioRecord状态
                if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                    Log.e(TAG, "AudioRecord initialized failed");
                    audioRecord = null;
                    return;
                }

                // 初始化音频缓冲区
                audioBuffer = new byte[bufferSize];
                isInitialized.set(true);
                Log.d(TAG, "AudioRecord init completed, min buffer size: " + bufferSize);

            } catch (Exception e) {
                Log.e(TAG, "AudioRecord init error:", e);
                isInitialized.set(false);
            }
        }, "AudioInitThread");

        audioThread.start();
    }

    public synchronized void startRecord() {
        if (isRecording.get()) {
            Log.w(TAG, "is recording, return");
            return;
        }

        // 等待初始化完成
        waitForInitialization();

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioRecord isInitialized is false");
            return;
        }

        Thread startThread = new Thread(() -> {
            synchronized (threadLock) {
                try {
                    if (audioRecord == null) {
                        Log.e(TAG, "AudioRecord is null");
                        return;
                    }

                    if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                        Log.e(TAG, "AudioRecord state is not STATE_INITIALIZED, return");
                        return;
                    }

                    // 开始录音
                    audioRecord.startRecording();
                    isRecording.set(true);
                    Log.d(TAG, "recording begins");

                    // 开始读取音频数据
                    startReadingAudioData();

                } catch (Exception e) {
                    Log.e(TAG, "startRecord Exception", e);
                    isRecording.set(false);
                }
            }
        }, "AudioStartThread");

        startThread.start();
    }

    public synchronized void stopRecord() {
        if (!isRecording.get()) {
            Log.w(TAG, "isRecording is false, return");
            return;
        }

        isRecording.set(false);

        Thread stopThread = new Thread(() -> {
            synchronized (threadLock) {
                try {
                    if (audioRecord != null) {
                        audioRecord.stop();
                        Log.d(TAG, "stop Record");
                    }
                } catch (Exception e) {
                    Log.e(TAG, "stop Record exception:", e);
                }

                // 等待录音线程结束
                if (recordThread != null && recordThread.isAlive()) {
                    try {
                        recordThread.join(1000); // 最多等待1秒
                    } catch (InterruptedException e) {
                        Log.w(TAG, "等待录音线程结束时被中断", e);
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }, "AudioStopThread");

        stopThread.start();
    }

    private void startReadingAudioData() {
        recordThread = new Thread(() -> {
            Log.d(TAG, "开始读取音频数据线程");

            while (isRecording.get()) {
                try {
                    if (audioRecord == null || !isRecording.get()) {
                        break;
                    }

                    // 读取音频数据
                    int bytesRead = audioRecord.read(audioBuffer, 0, bufferSize);

                    if (bytesRead > 0) {
                        // 计算音量
                        int volume = calculateVolume(audioBuffer, bytesRead);

                        // 创建数据副本
                        byte[] dataCopy = new byte[bytesRead];
                        System.arraycopy(audioBuffer, 0, dataCopy, 0, bytesRead);

                        // 通知监听器
                        notifyListeners(dataCopy, volume);
                    } else if (bytesRead < 0) {
                        Log.e(TAG, "读取音频数据失败，错误码: " + bytesRead);
                        break;
                    }

                    // 短暂休眠，避免过度占用CPU
                    Thread.sleep(1);

                } catch (InterruptedException e) {
                    Log.d(TAG, "录音线程被中断");
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    Log.e(TAG, "读取音频数据时发生异常", e);
                    break;
                }
            }

            Log.d(TAG, "音频数据读取线程结束");
        }, "AudioRecordThread");

        recordThread.start();
    }

    private void waitForInitialization() {
        if (audioThread != null && audioThread.isAlive()) {
            try {
                audioThread.join(3000); // 最多等待3秒
            } catch (InterruptedException e) {
                Log.d(TAG, "等待初始化时被中断", e);
                Thread.currentThread().interrupt();
            }
        }
    }

    private int calculateVolume(byte[] data, int length) {
        long sum = 0;
        for (int i = 0; i < length; i += 2) {
            // 16位PCM数据，每两个字节组成一个样本
            if (i + 1 < length) {
                short sample = (short) ((data[i + 1] << 8) | (data[i] & 0xFF));
                sum += Math.abs(sample);
            }
        }

        if (length > 0) {
            return (int) (sum / (length / 2));
        }
        return 0;
    }

    private void notifyListeners(byte[] data, int volume) {
        List<RecorderListener> listenersCopy;
        synchronized (listeners) {
            listenersCopy = new ArrayList<>(listeners);
        }

        for (RecorderListener listener : listenersCopy) {
            try {
                listener.onAudioBuffer(data, volume);
            } catch (Exception e) {
                Log.e(TAG, "通知监听器时发生异常", e);
            }
        }
    }

    public void registerListener(RecorderListener cb) {
        if (cb == null) {
            Log.w(TAG, "监听器为null，无法注册");
            return;
        }

        synchronized (listeners) {
            if (!listeners.contains(cb)) {
                listeners.add(cb);
                Log.d(TAG, "监听器注册成功，当前监听器数量: " + listeners.size());
            } else {
                Log.w(TAG, "监听器已存在，无需重复注册");
            }
        }
    }

    public void unregisterListener(RecorderListener cb) {
        if (cb == null) {
            Log.w(TAG, "监听器为null，无法注销");
            return;
        }

        synchronized (listeners) {
            if (listeners.remove(cb)) {
                Log.d(TAG, "监听器注销成功，当前监听器数量: " + listeners.size());
            } else {
                Log.w(TAG, "监听器不存在，无法注销");
            }
        }
    }

    public void release() {
        Log.d(TAG, "开始释放资源");

        // 停止录音
        stopRecord();

        // 在独立线程中释放AudioRecord
        Thread releaseThread = new Thread(() -> {
            synchronized (threadLock) {
                try {
                    // 等待所有操作完成
                    if (audioThread != null && audioThread.isAlive()) {
                        audioThread.join(1000);
                    }

                    if (recordThread != null && recordThread.isAlive()) {
                        recordThread.interrupt();
                        recordThread.join(1000);
                    }

                    // 释放AudioRecord
                    if (audioRecord != null) {
                        try {
                            audioRecord.release();
                            audioRecord = null;
                            Log.d(TAG, "AudioRecord已释放");
                        } catch (Exception e) {
                            Log.e(TAG, "释放AudioRecord时发生异常", e);
                        }
                    }

                } catch (InterruptedException e) {
                    Log.w(TAG, "等待线程结束时被中断", e);
                    Thread.currentThread().interrupt();
                } catch (Exception e) {
                    Log.e(TAG, "释放资源时发生异常", e);
                }
            }
        }, "AudioReleaseThread");

        releaseThread.start();

        // 清空监听器
        synchronized (listeners) {
            listeners.clear();
        }

        // 重置状态
        isRecording.set(false);
        isInitialized.set(false);

        Log.d(TAG, "资源释放完成");
    }

    public boolean isRecording() {
        return isRecording.get();
    }

    public boolean isInitialized() {
        return isInitialized.get();
    }

    public int getSampleRate() {
        return SAMPLE_RATE;
    }

    public int getBufferSize() {
        return bufferSize;
    }
}
