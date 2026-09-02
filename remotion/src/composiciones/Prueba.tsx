import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';

/**
 * Composición de humo: no depende de ningún archivo de entrada, así que sirve
 * para comprobar que el render funciona y para generar un video de muestra
 * con el que probar las demás composiciones.
 *
 *   npx remotion render Prueba public/entradas/muestra.mp4
 */
export const Prueba: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames, height} = useVideoConfig();

  const tono = interpolate(frame, [0, durationInFrames], [200, 340]);
  const segundo = (frame / fps).toFixed(1);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: `hsl(${tono}, 70%, 22%)`,
        justifyContent: 'center',
        alignItems: 'center',
        color: 'white',
        fontFamily: 'Arial, Helvetica, sans-serif',
      }}
    >
      <div style={{fontSize: height * 0.28, fontWeight: 800, fontVariantNumeric: 'tabular-nums'}}>
        {segundo}s
      </div>
      <div style={{fontSize: height * 0.06, opacity: 0.7}}>frame {frame}</div>
    </AbsoluteFill>
  );
};
