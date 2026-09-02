import React from 'react';
import {Composition} from 'remotion';
import {calcularMetadatos, EditarVideo} from './composiciones/EditarVideo';
import {Prueba} from './composiciones/Prueba';
import {calcularMetadatosSinSilencios, SinSilencios} from './composiciones/SinSilencios';
import {calcularMetadatosUnion, UnirClips} from './composiciones/UnirClips';
import {esquemaEditarVideo, esquemaSinSilencios, esquemaUnirClips} from './esquemas';

/**
 * Los valores de aquí son solo el punto de partida del Studio. Al renderizar
 * desde `scripts/render.mjs` se sobreescriben con las props que le pases.
 * El tamaño y la duración reales los calcula `calculateMetadata` leyendo el
 * video de origen.
 */
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="EditarVideo"
        component={EditarVideo}
        schema={esquemaEditarVideo}
        calculateMetadata={calcularMetadatos}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={300}
        defaultProps={{
          fuente: 'entradas/muestra.mp4',
          recorteDesde: 0,
          recorteHasta: null,
          velocidad: 1,
          volumen: 1,
          silenciar: false,
          fps: null,
          ancho: null,
          alto: null,
          ajuste: 'contener' as const,
          colorFondo: '#000000',
          intro: {
            titulo: '',
            subtitulo: '',
            duracion: 2,
            colorFondo: '#0f172a',
            colorTexto: '#ffffff',
          },
          marcaDeAgua: {
            texto: '',
            imagen: '',
            posicion: 'abajo-derecha' as const,
            opacidad: 0.85,
            tamano: 36,
            color: '#ffffff',
          },
          subtitulos: [],
          fundidoEntrada: 0,
          fundidoSalida: 0,
        }}
      />

      <Composition
        id="UnirClips"
        component={UnirClips}
        schema={esquemaUnirClips}
        calculateMetadata={calcularMetadatosUnion}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={300}
        defaultProps={{
          clips: [{fuente: 'entradas/muestra.mp4', desde: 0, hasta: null, silenciar: false}],
          fps: 30,
          ancho: 1920,
          alto: 1080,
          ajuste: 'contener' as const,
          colorFondo: '#000000',
          fundidoEntreClips: 0.4,
        }}
      />
      <Composition
        id="SinSilencios"
        component={SinSilencios}
        schema={esquemaSinSilencios}
        calculateMetadata={calcularMetadatosSinSilencios}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={300}
        defaultProps={{
          fuente: 'entradas/muestra.mp4',
          segmentos: [{desde: 0, hasta: 8}],
          fps: 30,
          ancho: 1920,
          alto: 1080,
          ajuste: 'contener' as const,
          colorFondo: '#000000',
          volumen: 1,
          rampaAudio: 0.02,
          encuadreAlterno: true,
          intensidadPunch: 0.18,
          puntoDeInteres: {x: 50, y: 42},
          zoomSutil: true,
          intensidadZoom: 0.03,
          marcaDeAgua: {
            texto: '',
            imagen: '',
            posicion: 'abajo-derecha' as const,
            opacidad: 0.85,
            tamano: 36,
            color: '#ffffff',
          },
          subtitulos: [],
          fundidoEntrada: 0.5,
          fundidoSalida: 0.8,
        }}
      />

      <Composition
        id="Prueba"
        component={Prueba}
        width={1280}
        height={720}
        fps={30}
        durationInFrames={240}
      />
    </>
  );
};
