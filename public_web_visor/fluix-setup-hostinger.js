/**
 * FLUIX SETUP PARA HOSTINGER - Carta del Restaurante
 * ====================================================
 * Añade los atributos de Fluix a los elementos existentes de Hostinger
 * SIN modificar el HTML ni romper el diseño.
 *
 * INSTRUCCIONES:
 * 1. En Hostinger Website Builder, añade un bloque "Custom Code" al FINAL de la página
 * 2. Pega el código <script> de abajo en ese bloque
 * 3. Publica la página
 * 4. Abre la página en el navegador, abre consola (F12) y ejecuta: Fluix.debug()
 * 5. Si todo está OK, ejecuta: Fluix.sincronizar()
 */

(function setupFluixCarta() {
    // ============================================================
    // CONFIGURACIÓN - Ajusta según tu empresa y sección
    // ============================================================
    const EMPRESA_ID  = 'ztZblwm1w71wNQtzHV7S';  // Tu empresa (fluixtech)
    const SECCION_ID  = 'carta';
    const TIPO        = 'carta';
    const TITULO      = 'Carta';
    // ID de la <section> en Hostinger (el id="z1Oz3q" del HTML)
    const BLOCK_ID    = 'z1Oz3q';

    // ============================================================
    // MAPA: { hostingerId → id del div texto en Hostinger, item, campo }
    // ============================================================
    const MAPA = [
        // ---- Paella Mixta ----
        { hostingerId: 'ai-7JVlSQ',  item: 'paella_mixta',       campo: 'nombre' },
        { hostingerId: 'ai-c9wmty',  item: 'paella_mixta',       campo: 'descripcion' },
        { hostingerId: 'ai-PPa5hQ',  item: 'paella_mixta',       campo: 'precio' },
        // ---- Tortilla Española ----
        { hostingerId: 'ai-SRuENI',  item: 'tortilla_espanola',  campo: 'nombre' },
        { hostingerId: 'ai-3y3igJ',  item: 'tortilla_espanola',  campo: 'descripcion' },
        { hostingerId: 'ai-SVrip_',  item: 'tortilla_espanola',  campo: 'precio' },
        // ---- Gazpacho ----
        { hostingerId: 'ai-J6nmoh',  item: 'gazpacho',           campo: 'nombre' },
        { hostingerId: 'ai-no3Odr',  item: 'gazpacho',           campo: 'descripcion' },
        { hostingerId: 'ai-hhwZTU',  item: 'gazpacho',           campo: 'precio' },
        // ---- Pulpo a la Gallega ----
        { hostingerId: 'ai-5HsDcs',  item: 'pulpo_gallega',      campo: 'nombre' },
        { hostingerId: 'ai-Ho562p',  item: 'pulpo_gallega',      campo: 'descripcion' },
        { hostingerId: 'ai-dKvHF-',  item: 'pulpo_gallega',      campo: 'precio' },
        // ---- Croquetas Caseras ----
        { hostingerId: 'ai-eEbZC6',  item: 'croquetas',          campo: 'nombre' },
        { hostingerId: 'ai-IqRj67',  item: 'croquetas',          campo: 'descripcion' },
        { hostingerId: 'ai-tEa_Ri',  item: 'croquetas',          campo: 'precio' },
    ];
    // ============================================================

    var startTime = Date.now();

    function setup() {
        // CORRECCIÓN: En el HTML publicado de Hostinger la section tiene id="z1Oz3q"
        // NO data-block-id, por eso usamos getElementById
        var section = document.getElementById(BLOCK_ID);

        if (!section) {
            if (Date.now() - startTime < 10000) {
                setTimeout(setup, 300);
            } else {
                console.error('Fluix Setup: No se encontró la section con id="' + BLOCK_ID + '"');
                console.error('Comprueba que BLOCK_ID es correcto mirando el HTML de tu página.');
            }
            return;
        }

        // 1. Marcar la sección como fluix-widget
        section.classList.add('fluix-widget');
        section.setAttribute('data-empresa', EMPRESA_ID);
        section.setAttribute('data-seccion', SECCION_ID);
        section.setAttribute('data-tipo', TIPO);
        section.setAttribute('data-titulo', TITULO);

        // 2. Añadir atributos fluix a cada campo
        var ok = 0;
        MAPA.forEach(function(entry) {
            // En Hostinger publicado los text-box tienen id="ai-XXXX" directamente
            var wrapper = document.getElementById(entry.hostingerId);

            if (wrapper) {
                // Buscar el elemento de texto real dentro del wrapper
                var textEl = wrapper.querySelector('strong, p, h6, h5, h4, h3, h2, h1');
                var target = textEl || wrapper;
                target.setAttribute('data-fluix-item', entry.item);
                target.setAttribute('data-fluix-campo', entry.campo);
                ok++;
            } else {
                console.warn('Fluix Setup: No encontrado #' + entry.hostingerId);
            }
        });

        console.log('✅ Fluix Setup: ' + ok + '/' + MAPA.length + ' campos configurados en la sección "' + SECCION_ID + '"');

        // 3. Cargar fluix-embed.js (con ?v= para evitar caché)
        if (!window._fluixEmbedCargado) {
            window._fluixEmbedCargado = true;
            var script = document.createElement('script');
            script.src = 'https://planeaapp-4bea4.web.app/fluix-embed.js?v=' + Date.now();
            script.onload = function() {
                console.log('✅ Fluix: Script cargado. Escucha de cambios activa.');
            };
            document.head.appendChild(script);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setup);
    } else {
        setup();
    }

})();
