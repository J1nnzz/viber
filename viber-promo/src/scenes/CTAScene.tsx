import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
} from "remotion";
import { COLORS } from "../colors";

export const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const textOpacity = interpolate(frame, [0, fps * 0.5], [0, 1], { extrapolateRight: "clamp" });
  const btnScale = spring({
    fps,
    frame: frame - fps * 0.3,
    config: { damping: 12, stiffness: 120 },
    durationInFrames: fps * 0.5,
  });
  const btnOpacity = interpolate(frame, [fps * 0.3, fps * 0.7], [0, 1], { extrapolateRight: "clamp" });

  // Fade out final
  const sceneOpacity = interpolate(frame, [fps * 1.5, fps * 2], [1, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 32,
        opacity: sceneOpacity,
      }}
    >
      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 36,
          fontWeight: 300,
          color: COLORS.gray,
          letterSpacing: 8,
          textTransform: "uppercase",
          opacity: textOpacity,
        }}
      >
        Disponible ahora
      </div>

      <div
        style={{
          opacity: btnOpacity,
          transform: `scale(${btnScale})`,
        }}
      >
        <div
          style={{
            background: `linear-gradient(135deg, ${COLORS.primary} 0%, ${COLORS.accent} 100%)`,
            borderRadius: 20,
            padding: "20px 64px",
            boxShadow: `0 20px 60px ${COLORS.primaryGlow}`,
          }}
        >
          <div
            style={{
              fontFamily: "'Helvetica Neue', Arial, sans-serif",
              fontSize: 28,
              fontWeight: 900,
              color: COLORS.white,
              letterSpacing: -1,
            }}
          >
            Descarga VIBER
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
