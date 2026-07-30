import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { COLORS } from "../colors";

export const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Texto aparece letra a letra (typewriter) a partir del frame 10
  const fullText = "¿Y si pudieras escuchar\nmúsica con tus amigos...";
  const charsToShow = Math.floor(
    interpolate(frame, [10, 10 + fullText.length * 1.2], [0, fullText.length], {
      extrapolateRight: "clamp",
      extrapolateLeft: "clamp",
    })
  );
  const displayText = fullText.slice(0, charsToShow);

  // "al mismo tiempo?" aparece después
  const subOpacity = interpolate(
    frame,
    [fps * 2.2, fps * 3],
    [0, 1],
    { extrapolateRight: "clamp", extrapolateLeft: "clamp" }
  );

  // Fade out al final (ajustado a 5s de escena)
  const sceneOpacity = interpolate(
    frame,
    [fps * 4.4, fps * 5],
    [1, 0],
    { extrapolateRight: "clamp", extrapolateLeft: "clamp" }
  );

  // Pulso de fondo sutil
  const pulseScale = 1 + 0.015 * Math.sin((frame / fps) * 2 * Math.PI);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        opacity: sceneOpacity,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 32,
      }}
    >
      {/* Glow de fondo */}
      <div
        style={{
          position: "absolute",
          width: 600,
          height: 600,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.primaryGlow} 0%, transparent 70%)`,
          transform: `scale(${pulseScale})`,
          opacity: 0.4,
        }}
      />

      {/* Texto principal */}
      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 68,
          fontWeight: 700,
          color: COLORS.white,
          textAlign: "center",
          lineHeight: 1.3,
          whiteSpace: "pre-line",
          zIndex: 1,
          letterSpacing: -1,
          textShadow: `0 0 60px ${COLORS.primaryGlow}`,
        }}
      >
        {displayText}
        {/* Cursor parpadeante */}
        {charsToShow < fullText.length && (
          <span
            style={{
              opacity: Math.floor(frame / 8) % 2 === 0 ? 1 : 0,
              color: COLORS.primaryLight,
            }}
          >
            |
          </span>
        )}
      </div>

      {/* Subtexto */}
      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 68,
          fontWeight: 700,
          color: COLORS.primaryLight,
          opacity: subOpacity,
          zIndex: 1,
          letterSpacing: -1,
        }}
      >
        al mismo tiempo?
      </div>
    </AbsoluteFill>
  );
};
