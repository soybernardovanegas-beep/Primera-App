import React from 'react';
import {AbsoluteFill, Img} from 'remotion';
import type {MarcaDeAguaProps} from '../esquemas';
import {resolverFuente} from '../metadatos';

const alineacion: Record<
  MarcaDeAguaProps['posicion'],
  {justifyContent: React.CSSProperties['justifyContent']; alignItems: React.CSSProperties['alignItems']}
> = {
  'arriba-izquierda': {justifyContent: 'flex-start', alignItems: 'flex-start'},
  'arriba-derecha': {justifyContent: 'flex-end', alignItems: 'flex-start'},
  'abajo-izquierda': {justifyContent: 'flex-start', alignItems: 'flex-end'},
  'abajo-derecha': {justifyContent: 'flex-end', alignItems: 'flex-end'},
  centro: {justifyContent: 'center', alignItems: 'center'},
};

export const MarcaDeAgua: React.FC<MarcaDeAguaProps> = ({
  texto,
  imagen,
  posicion,
  opacidad,
  tamano,
  color,
}) => {
  if (!texto && !imagen) {
    return null;
  }

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'row',
        gap: tamano * 0.5,
        padding: tamano,
        opacity: opacidad,
        ...alineacion[posicion],
      }}
    >
      {imagen ? (
        <Img src={resolverFuente(imagen)} style={{height: tamano * 2, objectFit: 'contain'}} />
      ) : null}
      {texto ? (
        <span
          style={{
            color,
            fontSize: tamano,
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontWeight: 700,
            textShadow: '0 2px 8px rgba(0,0,0,0.6)',
            whiteSpace: 'pre',
          }}
        >
          {texto}
        </span>
      ) : null}
    </AbsoluteFill>
  );
};
