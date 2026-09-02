import React from 'react';
import {AbsoluteFill, OffthreadVideo, Sequence, useVideoConfig} from 'remotion';
import type {CalculateMetadataFunction} from 'remotion';
import {Fundido} from '../componentes/Fundido';
import {Intro} from '../componentes/Intro';
import {MarcaDeAgua} from '../componentes/MarcaDeAgua';
import {Subtitulo} from '../componentes/Subtitulo';
import type {PropsEditarVideo} from '../esquemas';
import {aPar, leerMetadatos, resolverFuente} from '../metadatos';

/**
 * Lee el video de origen y ajusta duración, tamaño y fps de la composición
 * para que encajen con el recorte pedido. Remotion la llama antes de
 * renderizar y también cada vez que cambian las props en el Studio.
 */
export const calcularMetadatos: CalculateMetadataFunction<PropsEditarVideo> = async ({props}) => {
  const origen = await leerMetadatos(resolverFuente(props.fuente));

  const fps = props.fps ?? origen.fps;
  const recorteHasta = props.recorteHasta ?? origen.duracionEnSegundos;
  const segundosUtiles = Math.max(0, recorteHasta - props.recorteDesde) / props.velocidad;
  const segundosTotales = props.intro.duracion + segundosUtiles;

  return {
    fps,
    width: aPar(props.ancho ?? origen.ancho),
    height: aPar(props.alto ?? origen.alto),
    durationInFrames: Math.max(1, Math.round(segundosTotales * fps)),
    // Fijamos el final del recorte para que el componente no tenga que
    // volver a leer el archivo solo para saber cuánto dura.
    props: {...props, recorteHasta},
  };
};

export const EditarVideo: React.FC<PropsEditarVideo> = ({
  fuente,
  recorteDesde,
  recorteHasta,
  velocidad,
  volumen,
  silenciar,
  ajuste,
  colorFondo,
  intro,
  marcaDeAgua,
  subtitulos,
  fundidoEntrada,
  fundidoSalida,
}) => {
  const {fps, durationInFrames} = useVideoConfig();

  const framesIntro = intro.duracion > 0 && intro.titulo ? Math.round(intro.duracion * fps) : 0;
  const framesVideo = Math.max(1, durationInFrames - framesIntro);

  const desdeEnFrames = Math.round(recorteDesde * fps);
  // `recorteHasta` ya viene resuelto desde `calcularMetadatos`.
  const hastaEnFrames = Math.round((recorteHasta ?? recorteDesde) * fps);

  return (
    <AbsoluteFill style={{backgroundColor: colorFondo}}>
      {framesIntro > 0 ? (
        <Sequence durationInFrames={framesIntro} name="Intro">
          <Intro {...intro} />
        </Sequence>
      ) : null}

      <Sequence from={framesIntro} durationInFrames={framesVideo} name="Video">
        <OffthreadVideo
          src={resolverFuente(fuente)}
          trimBefore={desdeEnFrames}
          trimAfter={Math.max(desdeEnFrames + 1, hastaEnFrames)}
          playbackRate={velocidad}
          muted={silenciar}
          volume={silenciar ? 0 : volumen}
          style={{width: '100%', height: '100%', objectFit: ajuste === 'cubrir' ? 'cover' : 'contain'}}
        />
      </Sequence>

      {subtitulos.map((subtitulo, i) => {
        const inicio = framesIntro + Math.round(subtitulo.desde * fps);
        const duracion = Math.max(1, Math.round((subtitulo.hasta - subtitulo.desde) * fps));

        return (
          <Sequence
            key={`${subtitulo.desde}-${i}`}
            from={inicio}
            durationInFrames={duracion}
            name={`Subtítulo ${i + 1}`}
          >
            <Subtitulo texto={subtitulo.texto} />
          </Sequence>
        );
      })}

      <Sequence from={framesIntro} durationInFrames={framesVideo} name="Marca de agua">
        <MarcaDeAgua {...marcaDeAgua} />
      </Sequence>

      <Fundido
        entradaEnFrames={Math.round(fundidoEntrada * fps)}
        salidaEnFrames={Math.round(fundidoSalida * fps)}
      />
    </AbsoluteFill>
  );
};
