import {
  AbsoluteFill,
  Img,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  staticFile,
  Easing,
} from "remotion";
import { COLORS } from "../colors";
import { PhoneMockup } from "../components/PhoneMockup";

export const LoginScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const phoneY = spring({ fps, frame, config: { damping: 18, stiffness: 80 }, durationInFrames: fps });
  const translateY = interpolate(phoneY, [0, 1], [120, 0]);
  const phoneOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });

  // Zoom in suave — como si la cámara se acercara
  const zoomScale = interpolate(frame, [0, fps * 3.5], [1, 1.07], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const glowOpacity = 0.35 + 0.1 * Math.sin((frame / fps) * 1.5);

  const textOpacity = interpolate(frame, [fps * 0.8, fps * 1.4], [0, 1], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });
  const textY = interpolate(frame, [fps * 0.8, fps * 1.4], [20, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 40,
      }}
    >
      <div
        style={{
          position: "absolute",
          width: 500,
          height: 500,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.primaryGlow} 0%, transparent 65%)`,
          opacity: glowOpacity,
        }}
      />

      <div
        style={{
          opacity: phoneOpacity,
          transform: `translateY(${translateY}px) scale(${zoomScale})`,
          zIndex: 1,
        }}
      >
        <PhoneMockup>
          {/* Zoom lento sobre la imagen para dar movimiento */}
          <div style={{ width: "100%", height: "100%", overflow: "hidden" }}>
            <Img
              src={staticFile("screens/01_login.png")}
              style={{
                width: "110%",
                height: "110%",
                objectFit: "cover",
                marginLeft: "-5%",
                marginTop: `${interpolate(frame, [0, fps * 4], [-5, 0], { extrapolateRight: "clamp" })}%`,
              }}
            />
          </div>
        </PhoneMockup>
      </div>

      <div
        style={{
          opacity: textOpacity,
          transform: `translateY(${textY}px)`,
          textAlign: "center",
          zIndex: 1,
        }}
      >
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 36,
            fontWeight: 700,
            color: COLORS.white,
            letterSpacing: -1,
          }}
        >
          Acceso instantáneo.
        </div>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 20,
            color: COLORS.gray,
            marginTop: 8,
          }}
        >
          Con tu cuenta o con Google.
        </div>
      </div>
    </AbsoluteFill>
  );
};
