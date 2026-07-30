import React from "react";
import { Img, staticFile } from "remotion";
import { COLORS } from "../colors";

/**
 * iPhone frame PNG (1097 × 760 px) — análisis de píxeles exacto:
 *   Cuerpo opaco: x = 376–722  (346 px ancho)
 *                 y =  25–735  (710 px alto)
 *   Pantalla transparente (alpha = 0): y ≈ 80–721, interior del bisel lateral
 *   Dynamic Island opaco (negro): y ≈ 47–79
 *
 * Enfoque: el contenido llena TODO el cuerpo; el PNG actúa como máscara
 * natural — sus píxeles transparentes muestran el contenido, los opacos
 * (biseles, Dynamic Island, botones) lo tapan. Sin mix-blend-mode.
 */
const PNG_W  = 1097;
const PNG_H  = 760;
const BODY_X = 376;
const BODY_Y =  25;
const BODY_W = 346;   // 722 - 376
const BODY_H = 710;   // 735 -  25

export const PhoneMockup: React.FC<{
  children: React.ReactNode;
  scale?: number;
  glowColor?: string;
  /** Ángulo de inclinación en Y. - = gira izquierda, + = gira derecha */
  tiltY?: number;
}> = ({ children, scale = 1, glowColor = COLORS.primaryGlow, tiltY = -6 }) => {
  const W = BODY_W * scale;
  const H = BODY_H * scale;

  return (
    <div
      style={{
        position: "relative",
        width: W,
        height: H,
        flexShrink: 0,
        transform: tiltY !== 0
          ? `perspective(900px) rotateY(${tiltY}deg)`
          : undefined,
        filter: [
          "drop-shadow(0 28px 70px rgba(0,0,0,0.90))",
          `drop-shadow(0 0 45px ${glowColor})`,
        ].join(" "),
      }}
    >
      {/* Recorte al tamaño del cuerpo del teléfono.
          borderRadius medido de los píxeles del PNG (R≈71px a scale=1) */}
      <div style={{
        position: "absolute", inset: 0, overflow: "hidden",
        borderRadius: `${71 * scale}px`,
      }}>

        {/* ── Contenido: llena todo el cuerpo ──
            El PNG transparente hace de máscara natural:
            pantalla (alpha=0) → muestra el video
            biseles/botones (alpha>0) → tapan el video                */}
        <div style={{ position: "absolute", inset: 0, backgroundColor: "#000" }}>
          {children}
        </div>

        {/* ── Frame PNG posicionado para mostrar solo el cuerpo ── */}
        <Img
          src={staticFile("iphone-frame.png")}
          style={{
            position: "absolute",
            width:  PNG_W * scale,
            height: PNG_H * scale,
            left:  -BODY_X * scale,
            top:   -BODY_Y * scale,
            pointerEvents: "none",
            zIndex: 10,
          }}
        />
      </div>
    </div>
  );
};
