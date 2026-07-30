import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
  spring,
  Img,
  staticFile,
} from "remotion";
import { COLORS } from "../colors";

const AudioBars: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const bars = 7;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
      {Array.from({ length: bars }).map((_, i) => {
        const height = 20 + 40 * Math.abs(Math.sin((frame / fps) * 3 + i * 0.8));
        return (
          <div
            key={i}
            style={{
              width: 8,
              height,
              borderRadius: 4,
              background: `linear-gradient(180deg, ${COLORS.accent} 0%, ${COLORS.primary} 100%)`,
              transition: "height 0.1s",
            }}
          />
        );
      })}
    </div>
  );
};

export const LogoScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Logo entra con spring
  const logoScale = spring({
    fps,
    frame,
    config: { damping: 14, stiffness: 120 },
    durationInFrames: fps * 0.8,
  });

  const logoOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Tagline aparece después
  const taglineOpacity = interpolate(frame, [fps * 0.6, fps * 1.0], [0, 1], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });

  const taglineY = interpolate(frame, [fps * 0.6, fps * 1.0], [20, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Fade out
  const sceneOpacity = interpolate(frame, [fps * 2.6, fps * 3], [1, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        opacity: sceneOpacity,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 24,
      }}
    >
      {/* Glow */}
      <div
        style={{
          position: "absolute",
          width: 700,
          height: 700,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.primaryGlow} 0%, transparent 65%)`,
          opacity: logoScale * 0.6,
        }}
      />

      {/* Logo */}
      <div
        style={{
          opacity: logoOpacity,
          transform: `scale(${logoScale})`,
          zIndex: 1,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 20,
        }}
      >
        {/* Icono real de la app */}
        <div
          style={{
            width: 160,
            height: 160,
            borderRadius: 36,
            overflow: "hidden",
            boxShadow: `0 0 80px ${COLORS.primaryGlow}, 0 0 160px rgba(124,58,237,0.3)`,
          }}
        >
          <Img
            src={staticFile("app_icon.png")}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </div>

        {/* Nombre */}
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 110,
            fontWeight: 900,
            color: COLORS.white,
            letterSpacing: -4,
            background: `linear-gradient(135deg, ${COLORS.white} 0%, ${COLORS.accent} 100%)`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          VIBER
        </div>
      </div>

      {/* Tagline */}
      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 32,
          fontWeight: 400,
          color: COLORS.gray,
          letterSpacing: 6,
          textTransform: "uppercase",
          opacity: taglineOpacity,
          transform: `translateY(${taglineY}px)`,
          zIndex: 1,
        }}
      >
        Música en tiempo real
      </div>

      {/* Créditos — esquina inferior derecha */}
      <div
        style={{
          position: "absolute",
          bottom: 40,
          right: 60,
          opacity: taglineOpacity,
          zIndex: 2,
          display: "flex",
          alignItems: "center",
          gap: 20,
        }}
      >
        {/* Logo instituto */}
        <Img
          src={staticFile("nicolau.png")}
          style={{ height: 70, width: "auto", objectFit: "contain", opacity: 0.85 }}
        />

        {/* Separador */}
        <div style={{ width: 1, height: 50, background: "rgba(255,255,255,0.2)" }} />

        {/* Texto créditos */}
        <div style={{ textAlign: "right", display: "flex", flexDirection: "column", gap: 4 }}>
          <div
            style={{
              fontFamily: "'Helvetica Neue', Arial, sans-serif",
              fontSize: 12,
              fontWeight: 400,
              color: "rgba(255,255,255,0.4)",
              letterSpacing: 2,
              textTransform: "uppercase",
            }}
          >
            Made by
          </div>
          <div
            style={{
              fontFamily: "'Helvetica Neue', Arial, sans-serif",
              fontSize: 20,
              fontWeight: 700,
              color: COLORS.primaryLight,
              letterSpacing: 0.5,
            }}
          >
            Joel Zhu
          </div>
          <div
            style={{
              fontFamily: "'Helvetica Neue', Arial, sans-serif",
              fontSize: 12,
              fontWeight: 400,
              color: "rgba(255,255,255,0.35)",
              letterSpacing: 3,
              textTransform: "uppercase",
            }}
          >
            2DAM · T
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
