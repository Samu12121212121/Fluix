<?php
/**
 * Plugin Name: Fluix Blog Integration
 * Description: Renderiza artículos del blog de Fluix CRM con SEO server-side.
 * Version:     1.0
 * Author:      Fluix
 *
 * INSTALACIÓN:
 *   1. Guarda este archivo en wp-content/plugins/fluix-blog/fluix-blog.php
 *   2. Activa el plugin desde el panel de WordPress
 *   3. Edita las constantes FLUIX_EMPRESA_ID y FLUIX_BASE_URL abajo
 *
 * USO EN PLANTILLAS WORDPRESS:
 *   - Página del blog (lista):    <?php fluix_render_blog_lista(); ?>
 *   - Artículo individual:        <?php fluix_render_blog_entry(); ?>
 *   - O usar shortcodes:          [fluix_blog] / [fluix_blog_entry slug="mi-articulo"]
 */

// ── Configuración ─────────────────────────────────────────────────────────────
define('FLUIX_EMPRESA_ID', 'TU_EMPRESA_ID_AQUI');   // ← cambiar
define('FLUIX_BASE_URL',   'https://tusitio.com');   // ← cambiar (sin / al final)
define('FLUIX_API_BASE',   'https://europe-west1-planeaapp-4bea4.cloudfunctions.net');
define('FLUIX_CACHE_TTL',  900); // segundos (15 min)

if (!defined('ABSPATH')) exit;

// ── Caché con transients de WordPress ────────────────────────────────────────

function fluix_fetch(string $url): ?array {
    $cacheKey = 'fluix_' . md5($url);
    $cached   = get_transient($cacheKey);
    if ($cached !== false) return $cached;

    $res = wp_remote_get($url, [
        'timeout' => 8,
        'headers' => ['Accept' => 'application/json'],
    ]);

    if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
        return null;
    }

    $data = json_decode(wp_remote_retrieve_body($res), true);
    if (!empty($data['ok'])) {
        set_transient($cacheKey, $data, FLUIX_CACHE_TTL);
    }
    return $data ?: null;
}

// ── SEO: inyectar meta tags en <head> cuando hay una entrada Fluix ────────────

add_action('wp_head', function () {
    $slug = fluix_slug_actual();
    if (!$slug) return;

    $url  = FLUIX_API_BASE . '/getBlogEntry?empresaId=' . FLUIX_EMPRESA_ID
          . '&slug=' . urlencode($slug)
          . '&base=' . urlencode(FLUIX_BASE_URL);
    $data = fluix_fetch($url);
    if (!$data || empty($data['entrada'])) return;

    $e   = $data['entrada'];
    $seo = $e['seo'] ?? [];

    // Quitar título por defecto de WordPress en esta página
    remove_action('wp_head', '_wp_render_title_tag', 1);

    $title = esc_html($seo['title'] ?? $e['titulo'] ?? '');
    $desc  = esc_attr($seo['description'] ?? '');
    $img   = esc_url($seo['og_image'] ?? '');
    $canon = esc_url($seo['canonical'] ?? '');

    echo "<title>{$title}</title>\n";
    echo "<meta name='description' content='{$desc}'>\n";
    if (!empty($seo['keywords'])) {
        $kw = esc_attr(implode(', ', $seo['keywords']));
        echo "<meta name='keywords' content='{$kw}'>\n";
    }
    echo "<meta property='og:title' content='{$title}'>\n";
    echo "<meta property='og:description' content='{$desc}'>\n";
    if ($img)   echo "<meta property='og:image' content='{$img}'>\n";
    if ($canon) echo "<link rel='canonical' href='{$canon}'>\n";

    // JSON-LD schema.org
    if (!empty($e['json_ld'])) {
        $jsonLd = wp_json_encode($e['json_ld'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        echo "<script type='application/ld+json'>{$jsonLd}</script>\n";
    }
}, 1);

// ── Helper: slug del artículo desde la URL ────────────────────────────────────

function fluix_slug_actual(): string {
    // Adaptar según la estructura de URL de tu WordPress:
    // Ejemplo: /blog/mi-articulo → devuelve "mi-articulo"
    $path  = trim(parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?? '', '/');
    $partes = explode('/', $path);
    if (count($partes) >= 2 && $partes[0] === 'blog') {
        return sanitize_title($partes[1]);
    }
    return '';
}

// ── Render: artículo individual ───────────────────────────────────────────────

function fluix_render_blog_entry(string $slug = ''): void {
    if (!$slug) $slug = fluix_slug_actual();
    if (!$slug) { echo '<p>Artículo no encontrado.</p>'; return; }

    $url  = FLUIX_API_BASE . '/getBlogEntry?empresaId=' . FLUIX_EMPRESA_ID
          . '&slug=' . urlencode($slug)
          . '&base=' . urlencode(FLUIX_BASE_URL);
    $data = fluix_fetch($url);

    if (!$data || empty($data['entrada'])) {
        echo '<p>Este artículo no está disponible.</p>';
        return;
    }

    $e    = $data['entrada'];
    $date = !empty($e['fecha_publicacion'])
        ? date_i18n(get_option('date_format'), strtotime($e['fecha_publicacion']))
        : '';

    ob_start(); ?>
<article class="fluix-article" itemscope itemtype="https://schema.org/BlogPosting">
    <?php if (!empty($e['imagen_url'])): ?>
    <div class="fluix-hero-img">
        <img src="<?= esc_url($e['imagen_url']) ?>" alt="<?= esc_attr($e['titulo']) ?>"
             style="width:100%;max-height:480px;object-fit:cover;border-radius:12px">
    </div>
    <?php endif; ?>

    <header class="fluix-article-header" style="margin:32px 0 24px">
        <?php if (!empty($e['categoria'])): ?>
        <span class="fluix-categoria"
              style="background:#eff6ff;color:#2563eb;padding:4px 12px;border-radius:20px;font-size:13px;font-weight:600">
            <?= esc_html($e['categoria']) ?>
        </span>
        <?php endif; ?>

        <h1 itemprop="headline" style="margin-top:12px;font-size:2.2em;line-height:1.2">
            <?= esc_html($e['titulo']) ?>
        </h1>

        <div class="fluix-meta" style="display:flex;gap:16px;color:#6b7280;font-size:14px;margin-top:12px">
            <?php if (!empty($e['autor'])): ?>
            <span itemprop="author" itemscope itemtype="https://schema.org/Person">
                ✍️ <span itemprop="name"><?= esc_html($e['autor']) ?></span>
            </span>
            <?php endif; ?>
            <?php if ($date): ?>
            <time itemprop="datePublished" datetime="<?= esc_attr($e['fecha_publicacion']) ?>">
                📅 <?= $date ?>
            </time>
            <?php endif; ?>
            <?php if (!empty($e['tiempo_lectura_min'])): ?>
            <span>⏱ <?= (int)$e['tiempo_lectura_min'] ?> min de lectura</span>
            <?php endif; ?>
        </div>

        <?php if (!empty($e['etiquetas'])): ?>
        <div class="fluix-tags" style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap">
            <?php foreach ($e['etiquetas'] as $tag): ?>
            <span style="background:#f3f4f6;color:#374151;padding:3px 10px;border-radius:12px;font-size:12px">
                #<?= esc_html($tag) ?>
            </span>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </header>

    <div class="fluix-content" itemprop="articleBody"
         style="font-size:1.1em;line-height:1.8;color:#374151;max-width:760px">
        <?= $e['contenido_html'] /* ya viene saneado del servidor */ ?>
    </div>
</article>
    <?php
    echo ob_get_clean();
}

// ── Render: lista de artículos ────────────────────────────────────────────────

function fluix_render_blog_lista(int $limit = 9, string $categoria = ''): void {
    $url = FLUIX_API_BASE . '/getBlogLista?empresaId=' . FLUIX_EMPRESA_ID
         . '&limit=' . $limit
         . '&base=' . urlencode(FLUIX_BASE_URL);
    if ($categoria) $url .= '&categoria=' . urlencode($categoria);

    $data = fluix_fetch($url);
    if (!$data || empty($data['entradas'])) {
        echo '<p>No hay artículos publicados todavía.</p>';
        return;
    }

    ob_start(); ?>
<div class="fluix-blog-grid" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:24px">
    <?php foreach ($data['entradas'] as $e):
        $url_art = esc_url($e['url'] ?? (FLUIX_BASE_URL . '/blog/' . $e['slug']));
        $date    = !empty($e['fecha_publicacion'])
            ? date_i18n(get_option('date_format'), strtotime($e['fecha_publicacion']))
            : '';
    ?>
    <article class="fluix-card" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.06);transition:transform .2s"
             onmouseover="this.style.transform='translateY(-4px)'" onmouseout="this.style.transform=''">
        <?php if (!empty($e['imagen_url'])): ?>
        <a href="<?= $url_art ?>">
            <img src="<?= esc_url($e['imagen_url']) ?>" alt="<?= esc_attr($e['titulo']) ?>"
                 style="width:100%;height:200px;object-fit:cover" loading="lazy">
        </a>
        <?php endif; ?>

        <div style="padding:20px">
            <h2 style="font-size:1.1em;margin:0 0 8px;line-height:1.35">
                <a href="<?= $url_art ?>" style="color:#111827;text-decoration:none">
                    <?= esc_html($e['titulo']) ?>
                </a>
            </h2>
            <?php if (!empty($e['resumen'])): ?>
            <p style="color:#6b7280;font-size:14px;line-height:1.5;margin:0 0 12px">
                <?= esc_html(wp_trim_words($e['resumen'], 20)) ?>
            </p>
            <?php endif; ?>
            <div style="display:flex;justify-content:space-between;align-items:center;font-size:12px;color:#9ca3af">
                <span><?= $date ?></span>
                <?php if (!empty($e['tiempo_lectura_min'])): ?>
                <span><?= (int)$e['tiempo_lectura_min'] ?> min</span>
                <?php endif; ?>
            </div>
        </div>
    </article>
    <?php endforeach; ?>
</div>
    <?php
    echo ob_get_clean();
}

// ── Shortcodes ────────────────────────────────────────────────────────────────

add_shortcode('fluix_blog', function ($atts) {
    $a = shortcode_atts(['limit' => 9, 'categoria' => ''], $atts);
    ob_start();
    fluix_render_blog_lista((int)$a['limit'], $a['categoria']);
    return ob_get_clean();
});

add_shortcode('fluix_blog_entry', function ($atts) {
    $a = shortcode_atts(['slug' => ''], $atts);
    ob_start();
    fluix_render_blog_entry($a['slug']);
    return ob_get_clean();
});
