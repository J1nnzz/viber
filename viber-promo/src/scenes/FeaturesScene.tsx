import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  Easing,
} from "remotion";
import { COLORS } from "../colors";

const features = [
  { icon: "⚡", title: "WebSockets", desc: "Sin retrasos. Sin recargas." },
  { icon: "🎵", title: "YouTube integrado", desc: "Millones de canciones al instante." },
  { icon: "💬", title: "Chat en vivo", desc: "Habla mientras escuchas." },
  { icon: "🌍", title: "Desde cualquier lugar", desc: "Funciona en móvil y web." },
];

export const FeaturesScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleOpacity = interpolate(frame, [0, fps * 0.4], [0, 1], { extrapolateRight: "clamp" });
  const titleY = interpolate(frame, [0, fps * 0.4], [-30, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 48,
      }}
    >
      {/* Fondo con grid sutil */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `
            linear-gradient(rgba(124,58,237,0.05) 1px, transparent 1px),
            linear-gradient(90deg, rgba(124,58,237,0.05) 1px, transparent 1px)
          `,
          backgroundSize: "80px 80px",
        }}
      />

      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 52,
          fontWeight: 900,
          color: COLORS.white,
          letterSpacing: -2,
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          textAlign: "center",
        }}
      >
        La misma canción.{" "}
        <span
          style={{
            background: `linear-gradient(135deg, ${COLORS.primaryLight}, ${COLORS.accent})`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          Para todos.
        </span>
      </div>

      {/* Cards de features */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 24,
          zIndex: 1,
          width: 900,
        }}
      >
        {features.map((f, i) => {
          const delay = fps * 0.3 + i * fps * 0.2;
          const cardOpacity = interpolate(frame, [delay, delay + fps * 0.3], [0, 1], {
            extrapolateRight: "clamp",
            extrapolateLeft: "clamp",
          });
          const cardScale = spring({
            fps,
            frame: frame - delay,
            config: { damping: 14, stiffness: 120 },
            durationInFrames: fps * 0.4,
          });
          const cardY = interpolate(frame, [delay, delay + fps * 0.3], [30, 0], {
            extrapolateRight: "clamp",
            extrapolateLeft: "clamp",
            easing: Easing.out(Easing.cubic),
          });

          return (
            <div
              key={i}
              style={{
                backgroundColor: COLORS.bgCard,
                borderRadius: 20,
                padding: "28px 32px",
                border: `1px solid rgba(124,58,237,0.3)`,
                opacity: cardOpacity,
                transform: `scale(${cardScale}) translateY(${cardY}px)`,
                display: "flex",
                flexDirection: "column",
                gap: 12,
                boxShadow: `0 8px 40px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)`,
              }}
            >
              <div style={{ fontSize: 40 }}>{f.icon}</div>
              <div
                style={{
                  fontFamily: "'Helvetica Neue', Arial, sans-serif",
                  fontSize: 24,
                  fontWeight: 700,
                  color: COLORS.white,
                }}
              >
                {f.title}
              </div>
              <div
                style={{
                  fontFamily: "'Helvetica Neue', Arial, sans-serif",
                  fontSize: 16,
                  color: COLORS.gray,
                  lineHeight: 1.5,
                }}
              >
                {f.desc}
              </div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
