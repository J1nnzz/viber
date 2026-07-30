import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Sequence,
  Easing,
  spring,
} from "remotion";
import { COLORS } from "../colors";

// Mockup del móvil con pantalla de la app
const PhoneMockup: React.FC<{
  children: React.ReactNode;
  scale?: number;
}> = ({ children, scale = 1 }) => (
  <div
    style={{
      width: 340 * scale,
      height: 680 * scale,
      borderRadius: 48 * scale,
      backgroundColor: "#111120",
      border: `3px solid ${COLORS.grayDark}`,
      overflow: "hidden",
      boxShadow: `0 40px 120px rgba(0,0,0,0.8), 0 0 60px ${COLORS.primaryGlow}`,
      position: "relative",
    }}
  >
    {/* Notch */}
    <div
      style={{
        position: "absolute",
        top: 0,
        left: "50%",
        transform: "translateX(-50%)",
        width: 100 * scale,
        height: 28 * scale,
        backgroundColor: "#000",
        borderBottomLeftRadius: 20 * scale,
        borderBottomRightRadius: 20 * scale,
        zIndex: 10,
      }}
    />
    {children}
  </div>
);

// Pantalla Login
const LoginScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const btnScale = spring({ fps, frame: frame - 20, config: { damping: 12 }, durationInFrames: 25 });
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 20,
        padding: 32,
        boxSizing: "border-box",
      }}
    >
      <div style={{ fontSize: 42, fontWeight: 900, color: COLORS.white, letterSpacing: -2 }}>VIBER</div>
      <div style={{ fontSize: 13, color: COLORS.gray, marginBottom: 16 }}>Bienvenido de nuevo</div>
      <div
        style={{
          width: "100%",
          height: 44,
          borderRadius: 12,
          backgroundColor: COLORS.grayDark,
          border: `1px solid ${COLORS.primary}`,
          display: "flex",
          alignItems: "center",
          paddingLeft: 14,
        }}
      >
        <span style={{ fontSize: 13, color: COLORS.gray }}>usuario@email.com</span>
      </div>
      <div
        style={{
          width: "100%",
          height: 44,
          borderRadius: 12,
          backgroundColor: COLORS.grayDark,
          border: `1px solid rgba(255,255,255,0.1)`,
          display: "flex",
          alignItems: "center",
          paddingLeft: 14,
        }}
      >
        <span style={{ fontSize: 13, color: COLORS.gray }}>••••••••</span>
      </div>
      <div
        style={{
          width: "100%",
          height: 44,
          borderRadius: 12,
          background: `linear-gradient(135deg, ${COLORS.primary}, ${COLORS.accent})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${btnScale})`,
          boxShadow: `0 8px 30px ${COLORS.primaryGlow}`,
        }}
      >
        <span style={{ fontSize: 14, fontWeight: 700, color: COLORS.white }}>Entrar</span>
      </div>
      <div style={{ fontSize: 11, color: COLORS.gray }}>— o continúa con —</div>
      <div
        style={{
          width: "100%",
          height: 40,
          borderRadius: 12,
          backgroundColor: COLORS.grayDark,
          border: `1px solid rgba(255,255,255,0.1)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
        }}
      >
        <span style={{ fontSize: 16 }}>G</span>
        <span style={{ fontSize: 13, color: COLORS.white }}>Google</span>
      </div>
    </div>
  );
};

// Pantalla Salas
const RoomsScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const rooms = [
    { name: "Lo-fi study vibes 📚", users: 12, live: true },
    { name: "Reggaeton mix 🔥", users: 8, live: true },
    { name: "Rock clásico 🎸", users: 5, live: false },
    { name: "Chill beats 🌙", users: 20, live: true },
  ];

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        padding: "44px 16px 16px",
        boxSizing: "border-box",
        gap: 8,
      }}
    >
      <div style={{ fontSize: 20, fontWeight: 700, color: COLORS.white, marginBottom: 8 }}>Salas activas</div>
      {rooms.map((room, i) => {
        const cardOpacity = interpolate(frame, [i * 6, i * 6 + 12], [0, 1], { extrapolateRight: "clamp" });
        const cardY = interpolate(frame, [i * 6, i * 6 + 12], [20, 0], { extrapolateRight: "clamp" });
        return (
          <div
            key={i}
            style={{
              backgroundColor: COLORS.bgCard,
              borderRadius: 14,
              padding: "12px 14px",
              border: `1px solid ${room.live ? COLORS.primary : "rgba(255,255,255,0.05)"}`,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              opacity: cardOpacity,
              transform: `translateY(${cardY}px)`,
            }}
          >
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: COLORS.white }}>{room.name}</div>
              <div style={{ fontSize: 11, color: COLORS.gray }}>{room.users} oyentes</div>
            </div>
            {room.live && (
              <div
                style={{
                  backgroundColor: COLORS.primary,
                  borderRadius: 6,
                  padding: "3px 8px",
                  fontSize: 10,
                  fontWeight: 700,
                  color: COLORS.white,
                }}
              >
                EN VIVO
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};

// Pantalla Reproductor
const PlayerScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const spin = (frame / fps) * 20;
  const progress = interpolate(frame, [0, fps * 3], [0, 65], { extrapolateRight: "clamp" });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        padding: "44px 20px 20px",
        boxSizing: "border-box",
        gap: 16,
      }}
    >
      {/* Portada álbum */}
      <div
        style={{
          width: 200,
          height: 200,
          borderRadius: 20,
          background: `linear-gradient(135deg, ${COLORS.primary} 0%, #1a1a3e 50%, ${COLORS.accent} 100%)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 20px 60px ${COLORS.primaryGlow}`,
          transform: `rotate(${Math.sin(frame / 30) * 1}deg)`,
        }}
      >
        <div style={{ fontSize: 60 }}>🎵</div>
      </div>

      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: 18, fontWeight: 700, color: COLORS.white }}>Blinding Lights</div>
        <div style={{ fontSize: 13, color: COLORS.gray }}>The Weeknd</div>
      </div>

      {/* Barra de progreso */}
      <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 6 }}>
        <div
          style={{
            width: "100%",
            height: 4,
            backgroundColor: COLORS.grayDark,
            borderRadius: 2,
          }}
        >
          <div
            style={{
              width: `${progress}%`,
              height: "100%",
              background: `linear-gradient(90deg, ${COLORS.primary}, ${COLORS.accent})`,
              borderRadius: 2,
            }}
          />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ fontSize: 10, color: COLORS.gray }}>1:24</span>
          <span style={{ fontSize: 10, color: COLORS.gray }}>3:20</span>
        </div>
      </div>

      {/* Controles */}
      <div style={{ display: "flex", alignItems: "center", gap: 28 }}>
        {["⏮", "⏸", "⏭"].map((icon, i) => (
          <div
            key={i}
            style={{
              width: i === 1 ? 56 : 40,
              height: i === 1 ? 56 : 40,
              borderRadius: "50%",
              backgroundColor: i === 1 ? COLORS.primary : COLORS.grayDark,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: i === 1 ? 22 : 16,
              boxShadow: i === 1 ? `0 8px 30px ${COLORS.primaryGlow}` : "none",
            }}
          >
            {icon}
          </div>
        ))}
      </div>
    </div>
  );
};

// Pantalla Chat
const ChatScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const messages = [
    { user: "Carlos", text: "🔥🔥🔥 esta canción!", own: false },
    { user: "tú", text: "Sí!! me encanta", own: true },
    { user: "María", text: "alguien sabe cómo se llama?", own: false },
    { user: "tú", text: "The Weeknd - Blinding Lights", own: true },
    { user: "María", text: "graciasss 😍", own: false },
  ];

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        padding: "44px 12px 12px",
        boxSizing: "border-box",
        gap: 6,
      }}
    >
      <div style={{ fontSize: 14, fontWeight: 700, color: COLORS.white, marginBottom: 4 }}>Chat de la sala</div>
      {messages.map((msg, i) => {
        const msgOpacity = interpolate(frame, [i * 8, i * 8 + 10], [0, 1], { extrapolateRight: "clamp" });
        return (
          <div
            key={i}
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: msg.own ? "flex-end" : "flex-start",
              opacity: msgOpacity,
            }}
          >
            {!msg.own && (
              <span style={{ fontSize: 10, color: COLORS.primaryLight, marginBottom: 2 }}>{msg.user}</span>
            )}
            <div
              style={{
                backgroundColor: msg.own ? COLORS.primary : COLORS.grayDark,
                borderRadius: msg.own ? "14px 14px 4px 14px" : "14px 14px 14px 4px",
                padding: "8px 12px",
                maxWidth: "80%",
              }}
            >
              <span style={{ fontSize: 12, color: COLORS.white }}>{msg.text}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// Una sola "tarjeta de demo" con teléfono + label + keyword
const DemoCard: React.FC<{
  label: string;
  keyword: string;
  frame: number;
  fps: number;
  Screen: React.FC<{ frame: number; fps: number }>;
}> = ({ label, keyword, frame, fps, Screen }) => {
  const cardOpacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });
  const cardScale = spring({ fps, frame, config: { damping: 18, stiffness: 100 }, durationInFrames: 25 });

  const keywordOpacity = interpolate(frame, [fps * 0.4, fps * 0.7], [0, 1], {
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
        gap: 36,
        opacity: cardOpacity,
        transform: `scale(${cardScale})`,
      }}
    >
      {/* Glow */}
      <div
        style={{
          position: "absolute",
          width: 500,
          height: 500,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${COLORS.primaryGlow} 0%, transparent 65%)`,
          opacity: 0.3,
        }}
      />

      <PhoneMockup>
        <Screen frame={frame} fps={fps} />
      </PhoneMockup>

      <div style={{ textAlign: "center", zIndex: 1 }}>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 48,
            fontWeight: 900,
            color: COLORS.white,
            letterSpacing: -2,
            opacity: keywordOpacity,
          }}
        >
          {keyword}
        </div>
        <div
          style={{
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 18,
            color: COLORS.gray,
            marginTop: 4,
            opacity: keywordOpacity,
          }}
        >
          {label}
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const DemoScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // 4 tarjetas de 3 segundos cada una = 12 segundos total
  const segDur = fps * 3;

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg }}>
      <Sequence durationInFrames={segDur} premountFor={fps}>
        <DemoCard label="Acceso instantáneo" keyword="Entras." frame={frame} fps={fps} Screen={LoginScreen} />
      </Sequence>
      <Sequence from={segDur} durationInFrames={segDur} premountFor={fps}>
        <DemoCard
          label="Salas actualizadas en tiempo real"
          keyword="Eliges."
          frame={frame - segDur}
          fps={fps}
          Screen={RoomsScreen}
        />
      </Sequence>
      <Sequence from={segDur * 2} durationInFrames={segDur} premountFor={fps}>
        <DemoCard
          label="Millones de canciones desde YouTube"
          keyword="Suena."
          frame={frame - segDur * 2}
          fps={fps}
          Screen={PlayerScreen}
        />
      </Sequence>
      <Sequence from={segDur * 3} durationInFrames={segDur} premountFor={fps}>
        <DemoCard
          label="Chat en vivo mientras escuchas"
          keyword="Juntos."
          frame={frame - segDur * 3}
          fps={fps}
          Screen={ChatScreen}
        />
      </Sequence>
    </AbsoluteFill>
  );
};
