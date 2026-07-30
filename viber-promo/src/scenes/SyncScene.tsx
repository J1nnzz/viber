import {
  AbsoluteFill,
  Img,
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

const BEAT_FRAMES = 19;

const useBeat = (frame: number) => {
  const phase = (frame % BEAT_FRAMES) / BEAT_FRAMES;
  return Math.exp(-7 * phase);
};

// ── Mockup de laptop ─────────────────────────────────────────────────────────
/**
 * MacBook frame PNG (760 × 760 px) — análisis de píxeles exacto:
 *   Cuerpo opaco: x =  20–739  (719 px ancho)
 *                 y = 113–646  (533 px alto)
 *   Pantalla transparente (alpha = 0): y ≈ 133–480
 *   Teclado opaco (gris oscuro):       y ≈ 481–646
 *
 * Igual que PhoneMockup: el contenido llena el cuerpo entero y el PNG
 * actúa como máscara — pantalla transparente muestra el vídeo,
 * teclado/biseles opacos lo cubren. Sin mix-blend-mode.
 */
const MAC_PNG = 760;
const MAC_BX  =  20;
const MAC_BY  = 113;
const MAC_BW  = 719;   // 739 - 20
const MAC_BH  = 533;   // 646 - 113

const LaptopMockup: React.FC<{
  scale?: number;
  glowColor?: string;
  /** Ángulo de inclinación en Y. + = cara izquierda visible, - = cara derecha visible */
  tiltY?: number;
  children: React.ReactNode;
}> = ({ scale = 1, glowColor = "rgba(124,58,237,0.4)", tiltY = 0, children }) => {
  const W = MAC_BW * scale;
  const H = MAC_BH * scale;

  // Área de pantalla (hueco transparente del PNG) en % de las dimensiones del cuerpo:
  //   Horizontal: body_x 70 → 649 (ancho 579) de 719  →  left=9.74%  width=80.53%
  //   Vertical:   body_y 20 → 367 (alto  347) de 533  →  top=3.75%  height=65.10%
  // Las zonas body_x=0–66 y body_x=650+ son transparentes pero NO son pantalla:
  // deben verse vacías (fondo de página), no el vídeo.

  return (
    <div
      style={{
        transform: tiltY !== 0 ? `perspective(1200px) rotateY(${tiltY}deg)` : undefined,
        filter: [
          "drop-shadow(0 28px 70px rgba(0,0,0,0.90))",
          `drop-shadow(0 0 60px ${glowColor})`,
        ].join(" "),
      }}
    >
      <div style={{ position: "relative", width: W, height: H }}>
        {/* borderRadius medido de píxeles PNG: ~105px arriba (lid redondeado), ~20px abajo (base) */}
        <div style={{
          position: "absolute", inset: 0, overflow: "hidden",
          borderRadius: `${105 * scale}px ${105 * scale}px ${20 * scale}px ${20 * scale}px`,
        }}>

          {/* ── Contenido: sólo cubre el hueco transparente de la pantalla ──
              Las zonas laterales transparentes del PNG quedarán vacías
              (sin contenido detrás) y mostrarán el fondo de página.         */}
          <div style={{
            position: "absolute",
            left: "9.74%",
            top: "3.75%",
            width: "80.53%",
            height: "65.10%",
            overflow: "hidden",
            backgroundColor: "#000",
          }}>
            {children}
          </div>

          {/* ── Frame PNG (MacBook) ── */}
          <Img
            src={staticFile("macbook-frame.png")}
            style={{
              position: "absolute",
              width:  MAC_PNG * scale,
              height: MAC_PNG * scale,
              left:  -MAC_BX * scale,
              top:   -MAC_BY * scale,
              pointerEvents: "none",
              zIndex: 10,
            }}
          />
        </div>
      </div>
    </div>
  );
};

// ── Dispositivos ciclando (multiplataforma) ──────────────────────────────────
const DEVICES = [
  { emoji: "📱", label: "iOS & Android" },
  { emoji: "🌐", label: "Web App" },
  { emoji: "💻", label: "macOS & Windows" },
  { emoji: "📟", label: "Tablet" },
];
const DEVICE_FRAMES = 38;

const DeviceCycler: React.FC<{ frame: number; beat: number }> = ({ frame, beat }) => {
  const totalCycle = DEVICE_FRAMES * DEVICES.length;
  const pos = frame % totalCycle;
  const idx = Math.floor(pos / DEVICE_FRAMES);
  const phase = (pos % DEVICE_FRAMES) / DEVICE_FRAMES;
  const opacity =
    phase < 0.15 ? phase / 0.15 : phase > 0.8 ? (1 - phase) / 0.2 : 1;
  const device = DEVICES[idx];

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 6,
        opacity: opacity * (0.7 + beat * 0.3),
      }}
    >
      <div style={{ fontSize: 26, lineHeight: 1 }}>{device.emoji}</div>
      <div
        style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 11,
          fontWeight: 700,
          color: COLORS.primaryLight,
          letterSpacing: 3,
          textTransform: "uppercase",
        }}
      >
        {device.label}
      </div>
    </div>
  );
};

// ── Beam de conexión ─────────────────────────────────────────────────────────
const ConnectionBeam: React.FC<{ frame: number; beat: number; width: number }> = ({
  frame,
  beat,
  width,
}) => (
  <svg
    width={width}
    height={80}
    style={{ position: "absolute", overflow: "visible" }}
    viewBox={`0 0 ${width} 80`}
  >
    <defs>
      <filter id="glow" x="-20%" y="-100%" width="140%" height="300%">
        <feGaussianBlur stdDeviation="3" result="blur" />
        <feMerge>
          <feMergeNode in="blur" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
    </defs>
    <line x1={0} y1={40} x2={width} y2={40}
      stroke={`rgba(124,58,237,${0.2 + beat * 0.3})`} strokeWidth={1.5} strokeDasharray="6 6" />
    <line x1={0} y1={40} x2={width} y2={40}
      stroke={`rgba(168,85,247,${0.6 + beat * 0.4})`} strokeWidth={beat * 3}
      strokeLinecap="round" filter="url(#glow)" />
    {Array.from({ length: 5 }).map((_, i) => {
      const p = (frame * 0.018 + i * 0.2) % 1;
      const x = p * width;
      const op = Math.sin(p * Math.PI) * (0.6 + beat * 0.4);
      return (
        <g key={i}>
          <circle cx={x} cy={40} r={3 + beat * 2} fill={COLORS.primaryLight} opacity={op} />
          <circle cx={x} cy={40} r={6 + beat * 3} fill={COLORS.primaryLight} opacity={op * 0.3} />
        </g>
      );
    })}
    {Array.from({ length: 3 }).map((_, i) => {
      const p = (frame * 0.014 + i * 0.33 + 0.5) % 1;
      const x = (1 - p) * width;
      const op = Math.sin(p * Math.PI) * (0.4 + beat * 0.3);
      return <circle key={`r${i}`} cx={x} cy={40} r={2 + beat} fill={COLORS.accent} opacity={op} />;
    })}
    <circle cx={width / 2} cy={40} r={6 + beat * 8} fill="none"
      stroke={COLORS.primaryLight} strokeWidth={1.5} opacity={0.4 + beat * 0.6} />
    <circle cx={width / 2} cy={40} r={4} fill={COLORS.accent} opacity={0.8 + beat * 0.2} />
  </svg>
);

// ── Ondas de sonido ──────────────────────────────────────────────────────────
const PhoneWave: React.FC<{ frame: number; beat: number; side: "left" | "right" }> = ({
  frame, beat, side,
}) => {
  const dir = side === "left" ? -1 : 1;
  return (
    <>
      {[1, 2, 3].map((i) => {
        const phase = (Math.max(0, frame - i * 6) % BEAT_FRAMES) / BEAT_FRAMES;
        const scale = 1 + phase * i * 0.5;
        const opacity = Math.max(0, (1 - phase) * beat * 0.7);
        return (
          <div key={i} style={{
            position: "absolute",
            width: 200 * scale, height: 200 * scale,
            borderRadius: "50%",
            border: `1.5px solid ${COLORS.primaryLight}`,
            opacity,
            transform: `scaleX(${dir * 0.5}) translateX(${dir * 30}px)`,
            pointerEvents: "none",
          }} />
        );
      })}
    </>
  );
};

// ── Escena principal ─────────────────────────────────────────────────────────
export const SyncScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const beat = useBeat(frame);

  // Entrada de los dispositivos
  const leftSpring  = spring({ fps, frame,       config: { damping: 20, stiffness: 80 }, durationInFrames: fps });
  const rightSpring = spring({ fps, frame: frame - 8, config: { damping: 20, stiffness: 80 }, durationInFrames: fps });
  const leftX  = interpolate(leftSpring,  [0, 1], [-340, 0]);
  const rightX = interpolate(rightSpring, [0, 1], [340, 0]);

  const phoneBeat = 1 + beat * 0.025;

  // ── Morph del dispositivo derecho: teléfono → laptop ──
  // Empieza a los 2.5 s, termina a los 3.2 s dentro de la escena
  const MORPH_START = fps * 2.5;
  const MORPH_END   = fps * 3.2;
  const morphProgress = interpolate(frame, [MORPH_START, MORPH_END], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const phoneRightOpacity  = 1 - morphProgress;
  const laptopOpacity      = morphProgress;

  const beamOpacity = interpolate(frame, [fps * 0.5, fps * 1.2], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const badgeOpacity = interpolate(frame, [fps * 0.8, fps * 1.4], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const textOpacity = interpolate(frame, [fps * 1.2, fps * 1.8], [0, 1], {
    extrapolateRight: "clamp",
  });
  const textY = interpolate(frame, [fps * 1.2, fps * 1.8], [24, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const glowOpacity = 0.15 + beat * 0.2;
  const PHONE_SCALE  = 0.7;
  const BEAM_WIDTH   = 200;
  // MAC_BW=719 → scale=0.52 da ~374 px de ancho
  const LAPTOP_SCALE = 0.52;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.bg,
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 36,
      }}
    >
      {/* Glow de fondo */}
      <div style={{
        position: "absolute",
        width: 1000, height: 500,
        borderRadius: "50%",
        background: `radial-gradient(ellipse, rgba(124,58,237,${glowOpacity}) 0%, transparent 60%)`,
      }} />

      {/* Badge multiplataforma */}
      <div style={{
        opacity: badgeOpacity,
        zIndex: 2,
        display: "flex",
        alignItems: "center",
        gap: 14,
        backgroundColor: "rgba(124,58,237,0.15)",
        border: `1px solid rgba(168,85,247,0.3)`,
        borderRadius: 28,
        padding: "10px 28px",
        backdropFilter: "blur(8px)",
      }}>
        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 11, fontWeight: 700,
          color: "rgba(255,255,255,0.4)",
          letterSpacing: 3, textTransform: "uppercase",
        }}>
          Disponible en
        </div>
        <div style={{ width: 1, height: 24, background: "rgba(255,255,255,0.15)" }} />
        <DeviceCycler frame={frame} beat={beat} />
      </div>

      {/* Zona de los dos dispositivos + beam */}
      <div style={{ display: "flex", alignItems: "center", zIndex: 1, position: "relative" }}>

        {/* ── Dispositivo izquierdo: móvil (tiltY=-6 → cara derecha visible, mira al centro) ── */}
        <div style={{ transform: `translateX(${leftX}px) scale(${phoneBeat})`, position: "relative" }}>
          <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <PhoneWave frame={frame} beat={beat} side="left" />
          </div>
          <PhoneMockup
            scale={PHONE_SCALE}
            tiltY={-6}
            glowColor={`rgba(124,58,237,${0.4 + beat * 0.5})`}
          >
            <Video src={staticFile("screens/vid_sala_clean.mp4")} volume={0}
              style={{ width: "100%", height: "100%", objectFit: "cover" }} />
          </PhoneMockup>
        </div>

        {/* Beam central */}
        <div style={{
          width: BEAM_WIDTH, height: 80,
          opacity: beamOpacity,
          position: "relative",
          display: "flex", alignItems: "center", justifyContent: "center",
          flexShrink: 0,
        }}>
          <ConnectionBeam frame={frame} beat={beat} width={BEAM_WIDTH} />
          <div style={{
            position: "absolute", top: -24,
            fontFamily: "'Helvetica Neue', Arial, sans-serif",
            fontSize: 11, fontWeight: 700,
            color: COLORS.primaryLight,
            letterSpacing: 4,
            opacity: 0.7 + beat * 0.3,
          }}>
            EN SYNC
          </div>
        </div>

        {/* ── Dispositivo derecho: teléfono → laptop (tiltY=+6 → cara izquierda visible, mira al centro) ── */}
        <div style={{
          transform: `translateX(${rightX}px)`,
          position: "relative",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          width: 480,
          height: 480,
        }}>
          {/* Teléfono (desaparece con el morph) */}
          <div style={{
            position: "absolute",
            opacity: phoneRightOpacity,
            transform: `scale(${phoneBeat * (1 - morphProgress * 0.15)})`,
          }}>
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <PhoneWave frame={frame} beat={beat} side="right" />
            </div>
            <PhoneMockup
              scale={PHONE_SCALE}
              tiltY={6}
              glowColor={`rgba(168,85,247,${0.4 + beat * 0.5})`}
            >
              <Video src={staticFile("screens/vid_sala_clean.mp4")} startFrom={8} volume={0}
                style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </PhoneMockup>
          </div>

          {/* Laptop (aparece con el morph) */}
          <div style={{
            position: "absolute",
            opacity: laptopOpacity,
            transform: `scale(${phoneBeat * (0.85 + morphProgress * 0.15)})`,
          }}>
            <LaptopMockup
              scale={LAPTOP_SCALE}
              tiltY={6}
              glowColor={`rgba(168,85,247,${0.4 + beat * 0.5})`}
            >
              <Video src={staticFile("screens/viber-web.mp4")} volume={0}
                style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </LaptopMockup>
          </div>
        </div>
      </div>

      {/* Texto inferior */}
      <div style={{
        opacity: textOpacity,
        transform: `translateY(${textY}px)`,
        textAlign: "center",
        zIndex: 1,
      }}>
        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 44, fontWeight: 900,
          color: COLORS.white,
          letterSpacing: -2,
        }}>
          La misma canción.{" "}
          <span style={{
            background: `linear-gradient(135deg, ${COLORS.primaryLight}, ${COLORS.accent})`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}>
            Al mismo tiempo.
          </span>
        </div>
        <div style={{
          fontFamily: "'Helvetica Neue', Arial, sans-serif",
          fontSize: 20,
          color: COLORS.gray,
          marginTop: 12,
        }}>
          Sin importar dónde estés — ni desde qué dispositivo.
        </div>
      </div>
    </AbsoluteFill>
  );
};
