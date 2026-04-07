"""
Genera archivos MP3 mínimos de notificación para la app.
Ejecutar: python generar_sonidos.py

Requiere: pip install pydub
Si no tienes pydub, descarga los sonidos de https://mixkit.co/free-sound-effects/notification/
y renómbralos como se indica en assets/sounds/README.md
"""
import os
import struct
import math
import wave
import tempfile

SOUNDS_DIR = os.path.join(os.path.dirname(__file__), 'assets', 'sounds')

def generate_tone_wav(filename, freq=440, duration_ms=500, volume=0.5, sample_rate=44100):
    """Genera un tono WAV simple."""
    n_samples = int(sample_rate * duration_ms / 1000)
    samples = []
    for i in range(n_samples):
        t = i / sample_rate
        # Envelope (fade in/out)
        env = 1.0
        fade_samples = int(0.05 * sample_rate)
        if i < fade_samples:
            env = i / fade_samples
        elif i > n_samples - fade_samples:
            env = (n_samples - i) / fade_samples
        val = volume * env * math.sin(2 * math.pi * freq * t)
        samples.append(int(val * 32767))

    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f'<{len(samples)}h', *samples))

def generate_notification_wav(filename, freqs, duration_ms=200, gap_ms=100, volume=0.4):
    """Genera un sonido de notificación multi-tono."""
    sample_rate = 44100
    all_samples = []

    for freq in freqs:
        n_samples = int(sample_rate * duration_ms / 1000)
        for i in range(n_samples):
            t = i / sample_rate
            env = 1.0
            fade = int(0.02 * sample_rate)
            if i < fade: env = i / fade
            elif i > n_samples - fade: env = (n_samples - i) / fade
            val = volume * env * math.sin(2 * math.pi * freq * t)
            all_samples.append(int(val * 32767))
        # Gap
        gap_samples = int(sample_rate * gap_ms / 1000)
        all_samples.extend([0] * gap_samples)

    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f'<{len(all_samples)}h', *all_samples))

def generate_silence_wav(filename, duration_ms=100):
    """Genera silencio."""
    sample_rate = 44100
    n = int(sample_rate * duration_ms / 1000)
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f'<{n}h', *([0]*n)))

def main():
    os.makedirs(SOUNDS_DIR, exist_ok=True)

    # Usamos WAV ya que audioplayers soporta WAV nativo en Android/iOS
    sounds = {
        'notif_default': ([880, 1047], 150, 80, 0.35),
        'notif_urgente': ([1047, 1319, 1568], 120, 60, 0.5),
        'notif_suave': ([523, 659], 250, 120, 0.2),
        'notif_digital': ([1319, 1568, 1760], 80, 40, 0.3),
        'notif_clasico': ([784, 988, 784], 200, 100, 0.4),
    }

    for name, (freqs, dur, gap, vol) in sounds.items():
        wav_path = os.path.join(SOUNDS_DIR, f'{name}.wav')
        generate_notification_wav(wav_path, freqs, dur, gap, vol)
        print(f'✅ Generado: {wav_path}')

    # Silencio
    silence_path = os.path.join(SOUNDS_DIR, 'sin_sonido.wav')
    generate_silence_wav(silence_path, 100)
    print(f'✅ Generado: {silence_path}')

    print('\n🎵 Todos los sonidos generados en', SOUNDS_DIR)
    print('\nNota: Si prefieres MP3, convierte los WAV con ffmpeg:')
    print('  ffmpeg -i notif_default.wav notif_default.mp3')

if __name__ == '__main__':
    main()

