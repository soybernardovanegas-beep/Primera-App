import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';

/**
 * Un subtítulo. Va dentro de su propia `<Sequence>`, así que `useCurrentFrame`
 * ya devuelve el frame relativo a su propia aparición.
 */
export const Subtitulo: React.FC<{texto: string}> = ({texto}) => {
  const frame = useCurrentFrame();
  const {fps, height} = useVideoConfig();

  // Aparición suave en 0,2 s.
  const opacidad = interpolate(frame, [0, fps * 0.2], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        justifyContent: 'flex-end',
        alignItems: 'center',
        paddingBottom: height * 0.08,
      }}
    >
      <span
        style={{
          opacity: opacidad,
          maxWidth: '86%',
          textAlign: 'center',
          color: 'white',
          backgroundColor: 'rgba(0,0,0,0.65)',
          padding: `${height * 0.012}px ${height * 0.024}px`,
          borderRadius: height * 0.012,
          fontSize: height * 0.05,
          lineHeight: 1.25,
          fontFamily: 'Arial, Helvetica, sans-serif',
          fontWeight: 600,
        }}
      >
        {texto}
      </span>
    </AbsoluteFill>
  );
};
