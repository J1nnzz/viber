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

export const ExplorarScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // El móvil entra con un slide desde abajo + scale
  const enterSpring = spring({ fps, frame, config: { damping: 22, stiffness: 90 }, durationInFrames: fps });
  const translateY = interpolate(enterSpring, [0, 1], [80, 0]);
  const scaleIn = interpolate(enterSpring, [0, 1], [0.9, 1]);

  // Scroll camera — zoom out lento para revelar el tamaño de la app
  const scrollZoom = interpolate(frame, [fps * 0.5, fps * 4], [1.05, 0.98], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // Micro rotación opuesta — da sensación de explorar contenido
  const rotation = interpolate(frame, [0, fps * 4], [1.2, -0.5], {
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.sin),
  });

  const opacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });

  // Texto
  const textOpacity = interpolate(frame, [fps * 1, fps * 1.6], [0, 1], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });
  const textX = interpolate(frame, [fps * 1, fps * 1.6], [40, 0], {
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
        flexDirection: "row",
        gap: 80,
        opacity,
      }}
    >
      {/* Glow */}
      <div
        style={{
          position: "absolute",
          width: 600,
          height: 600,
          borderRadius: "50%",
          background: `radial-gradient(circle, rgba(168,85,247,0.2) 0%, transparent 65%)`,
          left: "15%",
          top: "20%",
        }}
      />

      {/* Móvil */}
      <div
        style={{
          transform: `translateY(${translateY}px) scale(${scaleIn * scrollZoom}) rotate(${rotation}deg)`,
          zIndex: 1,
        }}
      >
        <PhoneMockup glowColor="rgba(168,85,247,0.5)">
          <Video
            src={staticFile("screens/vid_explorar_real.mp4")}
            volume={0}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </PhoneMockup>
      </div>

      {/* Texto a la derecha */}
      <div
        style={{
          opacity: textOpacity,
          transform: `translateX(${textX}px)`,
          zIndex: 1,
          display: "flex",
          flexDirection: "column",
          gap: 20,
          maxWidth: 420,
        }}
      >
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 48,
            fontWeight: 900,
            color: COLORS.white,
            letterSpacing: -2,
            lineHeight: 1.15,
          }}
        >
          Descubre salas.{" "}
          <span
            style={{
              background: `linear-gradient(135deg, ${COLORS.primaryLight}, ${COLORS.accent})`,
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            Por género.
          </span>
        </div>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 20,
            color: COLORS.gray,
            lineHeight: 1.6,
          }}
        >
          Hip-Hop, Lo-fi, Rock, Pop...
          <br />
          Encuentra tu tribu.
        </div>
      </div>
    </AbsoluteFill>
  );
};
