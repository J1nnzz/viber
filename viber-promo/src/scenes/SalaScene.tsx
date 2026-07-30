import {
  AbsoluteFill,
  Video,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  staticFile,
  Easing,
} from "remotion";
import { COLORS } from "../colors";
import { PhoneMockup } from "../components/PhoneMockup";

// ~94 BPM → un beat cada ~19 frames a 30fps
const BEAT_FRAMES = 19;

const useBeat = (frame: number) => {
  const phase = (frame % BEAT_FRAMES) / BEAT_FRAMES;
  // Ataque rápido, caída exponencial — simula el kick
  return Math.exp(-7 * phase);
};

// Anillos que se expanden con el beat
const BeatRings: React.FC<{ frame: number; beat: number }> = ({ frame, beat }) => {
  const rings = [0, 0.33, 0.66];
  return (
    <>
      {rings.map((offset, i) => {
        const phase = ((frame + offset * BEAT_FRAMES) % BEAT_FRAMES) / BEAT_FRAMES;
        const scale = 1 + phase * 5.5;
        const opacity = Math.max(0, (1 - phase) * 0.55);
        const size = 220 + i * 30;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              width: size,
              height: size,
              borderRadius: "50%",
              border: `${2 - phase}px solid ${COLORS.primaryLight}`,
              transform: `scale(${scale})`,
              opacity,
              pointerEvents: "none",
            }}
          />
        );
      })}
    </>
  );
};

// Barras de frecuencia animadas en la parte inferior
const FreqBars: React.FC<{ frame: number; beat: number }> = ({ frame, beat }) => {
  const count = 28;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "flex-end",
        gap: 5,
        height: 80,
        padding: "0 8px",
      }}
    >
      {Array.from({ length: count }).map((_, i) => {
        const center = count / 2;
        const dist = Math.abs(i - center) / center;
        // Cada barra tiene su propia frecuencia + reacciona al beat
        const wave =
          0.3 +
          0.4 * Math.abs(Math.sin(frame * 0.12 + i * 0.6)) +
          0.3 * beat * (1 - dist * 0.6);
        const h = Math.max(6, wave * 76);
        return (
          <div
            key={i}
            style={{
              flex: 1,
              height: h,
              borderRadius: 3,
              background: `linear-gradient(180deg, ${COLORS.accent} 0%, ${COLORS.primary} 100%)`,
              opacity: 0.7 + beat * 0.3,
            }}
          />
        );
      })}
    </div>
  );
};

// Partículas flotantes que suben con el beat
const BeatParticles: React.FC<{ frame: number; beat: number }> = ({ frame, beat }) => {
  const particles = Array.from({ length: 10 }, (_, i) => i);
  return (
    <>
      {particles.map((i) => {
        const seed = i * 137.5;
        const x = ((seed * 3.7) % 100) - 50; // -50 a 50%
        const spawnPhase = (frame * 0.4 + i * 7) % 60;
        const progress = spawnPhase / 60;
        const y = -progress * 300;
        const opacity = Math.max(0, (0.8 - progress) * beat);
        const size = 4 + (seed % 6);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              bottom: 120,
              left: `calc(50% + ${x}px)`,
              width: size,
              height: size,
              borderRadius: "50%",
              backgroundColor: i % 2 === 0 ? COLORS.primaryLight : COLORS.accent,
              transform: `translateY(${y}px)`,
              opacity,
              pointerEvents: "none",
            }}
          />
        );
      })}
    </>
  );
};

export const SalaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const beat = useBeat(frame);

  // Entrada del teléfono
  const enterSpring = spring({ fps, frame, config: { damping: 18, stiffness: 80 }, durationInFrames: fps });
  const translateY = interpolate(enterSpring, [0, 1], [120, 0]);
  const opacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });

  // Zoom de cámara progresivo
  const zoomScale = interpolate(frame, [fps * 2, fps * 10], [1.0, 1.1], {
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // Pan suave hacia arriba
  const panY = interpolate(frame, [fps * 2, fps * 8], [0, -14], {
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.sin),
  });

  // El teléfono rebota ligeramente con el beat
  const phoneBounce = beat * 4;

  // Rotación suave de cámara
  const rotation = 0.5 * Math.sin((frame / fps) * 0.35);

  // Glow que pulsa con el beat
  const glowSize = 380 + beat * 160;
  const glowOpacity = 0.25 + beat * 0.35;

  // Píldora "Now playing"
  const pillOpacity = interpolate(frame, [fps * 0.8, fps * 1.4], [0, 1], {
    extrapolateRight: "clamp",
  });
  const pillY = interpolate(frame, [fps * 0.8, fps * 1.4], [20, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const pillPulse = 1 + beat * 0.06;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 28,
        opacity,
      }}
    >
      {/* Glow reactivo al beat */}
      <div
        style={{
          position: "absolute",
          width: glowSize,
          height: glowSize,
          borderRadius: "50%",
          background: `radial-gradient(circle, rgba(124,58,237,${glowOpacity}) 0%, transparent 65%)`,
          pointerEvents: "none",
        }}
      />

      {/* Anillos que se expanden con el beat */}
      <div style={{ position: "absolute", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <BeatRings frame={frame} beat={beat} />
      </div>

      {/* Partículas flotantes */}
      <BeatParticles frame={frame} beat={beat} />

      {/* Teléfono con movimiento de cámara + bounce del beat */}
      <div
        style={{
          transform: `translateY(${translateY + panY - phoneBounce}px) scale(${zoomScale}) rotate(${rotation}deg)`,
          transformOrigin: "center center",
          zIndex: 2,
        }}
      >
        <PhoneMockup glowColor={`rgba(124,58,237,${0.5 + beat * 0.4})`}>
          <Video
            src={staticFile("screens/vid_sala_clean.mp4")}
            volume={0}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </PhoneMockup>
      </div>

      {/* Barras de frecuencia debajo del teléfono */}
      <div style={{ zIndex: 2, width: 380 }}>
        <FreqBars frame={frame} beat={beat} />
      </div>

      {/* Píldora Now Playing */}
      <div
        style={{
          opacity: pillOpacity,
          transform: `translateY(${pillY}px) scale(${pillPulse})`,
          zIndex: 3,
          display: "flex",
          alignItems: "center",
          gap: 10,
          backgroundColor: `rgba(124,58,237,${0.8 + beat * 0.15})`,
          backdropFilter: "blur(8px)",
          borderRadius: 30,
          padding: "10px 22px",
          border: `1px solid rgba(168,85,247,0.5)`,
          boxShadow: `0 8px 32px rgba(124,58,237,${0.4 + beat * 0.3})`,
        }}
      >
        <span style={{ fontSize: 18 }}>🎵</span>
        <div>
          <div style={{ fontFamily: "'Helvetica Neue', Arial, sans-serif", fontSize: 13, fontWeight: 700, color: COLORS.white }}>
            Passionfruit
          </div>
          <div style={{ fontFamily: "'Helvetica Neue', Arial, sans-serif", fontSize: 11, color: "rgba(255,255,255,0.7)" }}>
            Drake · Escuchando juntos
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
