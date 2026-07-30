import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  Easing,
} from "remotion";
import { COLORS } from "../colors";

const WaveRings: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => (
  <>
    {[0, 1, 2, 3].map((i) => {
      const delay = i * fps * 0.35;
      const progress = Math.max(0, ((frame - delay) % (fps * 2)) / (fps * 2));
      const scale = 0.5 + progress * 3.5;
      const opacity = Math.max(0, 0.45 - progress * 0.45);
      return (
        <div
          key={i}
          style={{
            position: "absolute",
            width: 160,
            height: 160,
            borderRadius: "50%",
            border: `1.5px solid ${COLORS.primaryLight}`,
            transform: `scale(${scale})`,
            opacity,
          }}
        />
      );
    })}
  </>
);

export const ClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const line1Opacity = interpolate(frame, [0, fps * 0.6], [0, 1], { extrapolateRight: "clamp" });
  const line1Y = interpolate(frame, [0, fps * 0.6], [40, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const line2Opacity = interpolate(frame, [fps * 0.7, fps * 1.3], [0, 1], { extrapolateRight: "clamp" });
  const line2Y = interpolate(frame, [fps * 0.7, fps * 1.3], [40, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const logoScale = spring({
    fps,
    frame: frame - fps * 1.6,
    config: { damping: 12, stiffness: 100 },
    durationInFrames: fps * 0.7,
  });
  const logoOpacity = interpolate(frame, [fps * 1.6, fps * 2.2], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 28,
      }}
    >
      <div
        style={{
          position: "absolute",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <WaveRings frame={frame} fps={fps} />
      </div>

      <div
        style={{
          position: "absolute",
          width: 450,
          height: 450,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.primaryGlow} 0%, transparent 65%)`,
          opacity: 0.45,
        }}
      />

      <div style={{ textAlign: "center", zIndex: 1, display: "flex", flexDirection: "column", gap: 12 }}>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 28,
            fontWeight: 300,
            color: COLORS.gray,
            letterSpacing: 4,
            textTransform: "uppercase",
            opacity: line1Opacity,
            transform: `translateY(${line1Y}px)`,
          }}
        >
          Viber.
        </div>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 62,
            fontWeight: 900,
            letterSpacing: -3,
            lineHeight: 1.1,
            opacity: line2Opacity,
            transform: `translateY(${line2Y}px)`,
            background: `linear-gradient(135deg, ${COLORS.white} 20%, ${COLORS.accent} 100%)`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          Que la música
          <br />
          te conecte.
        </div>
      </div>

      <div
        style={{
          opacity: logoOpacity,
          transform: `scale(${logoScale})`,
          zIndex: 1,
          marginTop: 8,
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 22,
          fontWeight: 400,
          color: COLORS.gray,
          letterSpacing: 8,
          textTransform: "uppercase",
        }}
      >
        viber · app
      </div>
    </AbsoluteFill>
  );
};
