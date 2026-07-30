import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { COLORS } from "../colors";

export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Logo entra con spring suave
  const logoSpring = spring({
    fps, frame,
    config: { damping: 20, stiffness: 55 },
    durationInFrames: fps,
  });
  const logoOpacity = interpolate(logoSpring, [0, 1], [0, 1]);
  const logoY       = interpolate(logoSpring, [0, 1], [30, 0]);

  // Texto aparece después
  const textOpacity = interpolate(frame, [fps * 0.9, fps * 1.5], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const textY = interpolate(frame, [fps * 0.9, fps * 1.5], [20, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Fade out suave al final
  const sceneOpacity = interpolate(frame, [fps * 2.3, fps * 3], [1, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 36,
        opacity: sceneOpacity,
      }}
    >
      {/* Glow muy sutil */}
      <div style={{
        position: "absolute",
        width: 700, height: 700,
        borderRadius: "50%",
        background: "radial-gradient(circle, rgba(124,58,237,0.07) 0%, transparent 65%)",
        pointerEvents: "none",
      }} />

      {/* Logo del instituto */}
      <div style={{
        opacity: logoOpacity,
        transform: `translateY(${logoY}px)`,
        zIndex: 1,
      }}>
        <Img
          src={staticFile("nicolau.png")}
          style={{ height: 160, width: "auto", objectFit: "contain" }}
        />
      </div>

      {/* Línea separadora con gradiente */}
      <div style={{
        opacity: textOpacity,
        width: 1,
        height: 56,
        background: "linear-gradient(180deg, transparent 0%, rgba(168,85,247,0.7) 50%, transparent 100%)",
        zIndex: 1,
      }} />

      {/* Créditos */}
      <div style={{
        opacity: textOpacity,
        transform: `translateY(${textY}px)`,
        textAlign: "center",
        zIndex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 10,
      }}>
        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 13,
          fontWeight: 400,
          color: "rgba(255,255,255,0.35)",
          letterSpacing: 5,
          textTransform: "uppercase",
        }}>
          Proyecto DAM · ABP4
        </div>

        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 13,
          fontWeight: 300,
          color: "rgba(255,255,255,0.28)",
          letterSpacing: 3,
          textTransform: "uppercase",
          marginTop: 4,
        }}>
          Presentado por
        </div>

        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 42,
          fontWeight: 800,
          color: COLORS.white,
          letterSpacing: -1,
          lineHeight: 1.1,
        }}>
          Joel Zhu
        </div>

        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 15,
          fontWeight: 600,
          color: COLORS.primaryLight,
          letterSpacing: 6,
          textTransform: "uppercase",
        }}>
          2DAM · T
        </div>
      </div>
    </AbsoluteFill>
  );
};
