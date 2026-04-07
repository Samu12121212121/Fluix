<?php
/**
 * Plugin Name: PlaneaGuada CRM Integration
 * Description: Integración bidireccional entre WordPress y PlaneaGuada CRM Flutter App
 * Version: 1.0.0
 * Author: PlaneaGuada Team
 */

// Evitar acceso directo
if (!defined('ABSPATH')) {
    exit;
}

class PlaneaGuadaCRMIntegration {

    private $firebase_project_id;
    private $firebase_api_key;
    private $empresa_id;

    public function __construct() {
        // TODO: Configurar con tus datos de Firebase
        $this->firebase_project_id = 'tu-proyecto-firebase';
        $this->firebase_api_key = 'tu-api-key';
        $this->empresa_id = 'tu-empresa-id';

        add_action('init', [$this, 'init']);
        add_action('rest_api_init', [$this, 'register_rest_routes']);

        // Hooks para formularios de contacto
        add_action('wpcf7_mail_sent', [$this, 'handle_contact_form_submission']);

        // Hooks para comentarios/reseñas
        add_action('comment_post', [$this, 'handle_new_comment'], 10, 3);

        // Hooks para reservas (si usas plugin de reservas)
        add_action('booking_confirmed', [$this, 'handle_new_booking']);

        // Programar sincronización de estadísticas
        add_action('wp', [$this, 'schedule_stats_sync']);
        add_action('planeaguada_sync_stats', [$this, 'sync_stats_to_firebase']);
    }

    public function init() {
        // Inicialización del plugin
        add_action('admin_menu', [$this, 'add_admin_menu']);
        add_action('admin_init', [$this, 'register_settings']);
    }

    public function register_rest_routes() {
        // Endpoint para estadísticas
        register_rest_route('planeaguada/v1', '/stats', [
            'methods' => 'GET',
            'callback' => [$this, 'get_wordpress_stats'],
            'permission_callback' => '__return_true'
        ]);

        // Endpoint para recibir actualizaciones del CRM
        register_rest_route('planeaguada/v1', '/reservas/(?P<id>[\d]+)', [
            'methods' => 'PUT',
            'callback' => [$this, 'update_reservation_status'],
            'permission_callback' => [$this, 'verify_crm_permission']
        ]);

        // Endpoint para respuestas a reseñas
        register_rest_route('planeaguada/v1', '/reviews/(?P<id>[\d]+)/reply', [
            'methods' => 'POST',
            'callback' => [$this, 'add_review_reply'],
            'permission_callback' => [$this, 'verify_crm_permission']
        ]);

        // Endpoint para reseñas
        register_rest_route('planeaguada/v1', '/reviews', [
            'methods' => 'GET',
            'callback' => [$this, 'get_reviews'],
            'permission_callback' => '__return_true'
        ]);
    }

    /**
     * Maneja envíos de formularios de contacto
     */
    public function handle_contact_form_submission($contact_form) {
        $submission = WPCF7_Submission::get_instance();
        if (!$submission) return;

        $posted_data = $submission->get_posted_data();

        // Extraer datos del formulario
        $reservation_data = [
            'client_name' => $posted_data['your-name'] ?? '',
            'client_email' => $posted_data['your-email'] ?? '',
            'client_phone' => $posted_data['your-phone'] ?? '',
            'service' => $posted_data['service'] ?? '',
            'appointment_date' => $posted_data['appointment-date'] ?? '',
            'notes' => $posted_data['your-message'] ?? '',
            'status' => 'pendiente',
            'created_at' => current_time('mysql'),
            'origin' => 'wordpress_form'
        ];

        // Enviar a Firebase
        $this->send_to_firebase('reservas', $reservation_data);

        // Opcional: Guardar localmente en WordPress
        $this->save_reservation_locally($reservation_data);
    }

    /**
     * Maneja nuevos comentarios/reseñas
     */
    public function handle_new_comment($comment_id, $comment_approved, $commentdata) {
        if ($comment_approved !== 1) return; // Solo comentarios aprobados

        $comment = get_comment($comment_id);
        $post = get_post($comment->comment_post_ID);

        // Verificar si tiene rating (si usas plugin de reseñas)
        $rating = get_comment_meta($comment_id, 'rating', true) ?: 5;

        $review_data = [
            'id' => $comment_id,
            'author_name' => $comment->comment_author,
            'author_email' => $comment->comment_author_email,
            'content' => $comment->comment_content,
            'rating' => (int)$rating,
            'date' => $comment->comment_date,
            'status' => 'approved',
            'post_title' => $post->post_title,
            'post_url' => get_permalink($post->ID)
        ];

        // Enviar a Firebase
        $this->send_to_firebase('valoraciones', $review_data);
    }

    /**
     * Obtiene estadísticas de WordPress
     */
    public function get_wordpress_stats($request) {
        $current_month = date('Y-m');
        $previous_month = date('Y-m', strtotime('-1 month'));

        // Estadísticas básicas de WordPress
        $stats = [
            'visitas_mes' => $this->get_monthly_visits($current_month),
            'visitas_mes_pasado' => $this->get_monthly_visits($previous_month),
            'total_posts' => wp_count_posts()->publish,
            'comentarios_mes' => $this->get_monthly_comments($current_month),
            'paginas_vistas' => $this->get_monthly_page_views($current_month),
            'tiempo_promedio' => $this->get_average_time_on_site(),
            'usuarios_registrados' => count_users()['total_users'],
            'ultima_actualizacion' => current_time('mysql')
        ];

        // Si tienes Google Analytics, puedes obtener datos más precisos
        if (function_exists('ga_get_stats')) {
            $ga_stats = ga_get_stats($current_month);
            $stats = array_merge($stats, $ga_stats);
        }

        return new WP_REST_Response($stats, 200);
    }

    /**
     * Obtiene reseñas para el CRM
     */
    public function get_reviews($request) {
        $empresa_id = $request->get_param('empresa_id');
        $limit = $request->get_param('limit') ?: 15;

        $comments = get_comments([
            'status' => 'approve',
            'number' => $limit,
            'orderby' => 'comment_date',
            'order' => 'DESC',
            'meta_query' => [
                [
                    'key' => 'rating',
                    'compare' => 'EXISTS'
                ]
            ]
        ]);

        $reviews = [];
        foreach ($comments as $comment) {
            $rating = get_comment_meta($comment->comment_ID, 'rating', true) ?: 5;
            $reply = get_comment_meta($comment->comment_ID, 'admin_reply', true);

            $reviews[] = [
                'id' => $comment->comment_ID,
                'author_name' => $comment->comment_author,
                'author_email' => $comment->comment_author_email,
                'content' => $comment->comment_content,
                'rating' => (int)$rating,
                'date' => $comment->comment_date,
                'reply' => $reply,
                'status' => $comment->comment_approved,
                'post_title' => get_the_title($comment->comment_post_ID)
            ];
        }

        return new WP_REST_Response(['reviews' => $reviews], 200);
    }

    /**
     * Actualiza estado de reserva desde el CRM
     */
    public function update_reservation_status($request) {
        $reservation_id = $request['id'];
        $new_status = $request['estado'];
        $empresa_id = $request['empresa_id'];

        // Actualizar en base de datos local
        global $wpdb;
        $table_name = $wpdb->prefix . 'planeaguada_reservations';

        $updated = $wpdb->update(
            $table_name,
            ['status' => $new_status, 'updated_at' => current_time('mysql')],
            ['id' => $reservation_id],
            ['%s', '%s'],
            ['%d']
        );

        if ($updated !== false) {
            // Enviar email al cliente
            $this->send_reservation_email($reservation_id, $new_status);
            return new WP_REST_Response(['success' => true], 200);
        }

        return new WP_REST_Response(['error' => 'No se pudo actualizar'], 500);
    }

    /**
     * Añade respuesta a reseña desde el CRM
     */
    public function add_review_reply($request) {
        $review_id = $request['id'];
        $reply = $request['respuesta'];
        $empresa_id = $request['empresa_id'];

        // Guardar respuesta como meta del comentario
        $saved = update_comment_meta($review_id, 'admin_reply', $reply);

        if ($saved) {
            // Opcional: Enviar email al autor de la reseña
            $this->notify_review_author($review_id, $reply);
            return new WP_REST_Response(['success' => true], 200);
        }

        return new WP_REST_Response(['error' => 'No se pudo guardar respuesta'], 500);
    }

    /**
     * Envía datos a Firebase
     */
    private function send_to_firebase($collection, $data) {
        $firebase_url = "https://firestore.googleapis.com/v1/projects/{$this->firebase_project_id}/databases/(default)/documents/empresas/{$this->empresa_id}/{$collection}";

        $payload = [
            'fields' => $this->convert_to_firestore_format($data)
        ];

        $response = wp_remote_post($firebase_url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->firebase_api_key,
                'Content-Type' => 'application/json'
            ],
            'body' => json_encode($payload),
            'timeout' => 30
        ]);

        if (is_wp_error($response)) {
            error_log('Error enviando a Firebase: ' . $response->get_error_message());
            return false;
        }

        return true;
    }

    /**
     * Convierte datos a formato Firestore
     */
    private function convert_to_firestore_format($data) {
        $firestore_data = [];

        foreach ($data as $key => $value) {
            if (is_string($value)) {
                $firestore_data[$key] = ['stringValue' => $value];
            } elseif (is_int($value)) {
                $firestore_data[$key] = ['integerValue' => $value];
            } elseif (is_float($value)) {
                $firestore_data[$key] = ['doubleValue' => $value];
            } elseif (is_bool($value)) {
                $firestore_data[$key] = ['booleanValue' => $value];
            } else {
                $firestore_data[$key] = ['stringValue' => (string)$value];
            }
        }

        return $firestore_data;
    }

    /**
     * Obtiene visitas mensuales
     */
    private function get_monthly_visits($month) {
        // Implementar según tu plugin de analytics
        // Ejemplo con Google Analytics
        if (function_exists('ga_get_monthly_visits')) {
            return ga_get_monthly_visits($month);
        }

        // Fallback: usar visitas de posts
        global $wpdb;
        $visits = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->prefix}posts
             WHERE post_type = 'post'
             AND post_status = 'publish'
             AND DATE_FORMAT(post_date, '%%Y-%%m') = %s",
            $month
        ));

        return $visits ?: 0;
    }

    /**
     * Programar sincronización de estadísticas
     */
    public function schedule_stats_sync() {
        if (!wp_next_scheduled('planeaguada_sync_stats')) {
            wp_schedule_event(time(), 'hourly', 'planeaguada_sync_stats');
        }
    }

    /**
     * Sincronizar estadísticas a Firebase
     */
    public function sync_stats_to_firebase() {
        $stats = $this->get_wordpress_stats(new WP_REST_Request());
        $this->send_to_firebase('estadisticas/wordpress_data', $stats->get_data());
    }

    /**
     * Verificar permisos del CRM
     */
    public function verify_crm_permission($request) {
        // TODO: Implementar verificación de API key o token
        $api_key = $request->get_header('X-API-Key');
        return $api_key === 'tu-api-key-secreta';
    }

    /**
     * Añadir menú de administración
     */
    public function add_admin_menu() {
        add_options_page(
            'PlaneaGuada CRM',
            'PlaneaGuada CRM',
            'manage_options',
            'planeaguada-crm',
            [$this, 'admin_page']
        );
    }

    /**
     * Página de administración
     */
    public function admin_page() {
        ?>
        <div class="wrap">
            <h1>PlaneaGuada CRM Integration</h1>
            <form method="post" action="options.php">
                <?php
                settings_fields('planeaguada_settings');
                do_settings_sections('planeaguada_settings');
                ?>
                <table class="form-table">
                    <tr>
                        <th scope="row">Firebase Project ID</th>
                        <td><input type="text" name="planeaguada_firebase_project" value="<?php echo esc_attr(get_option('planeaguada_firebase_project')); ?>" /></td>
                    </tr>
                    <tr>
                        <th scope="row">Empresa ID</th>
                        <td><input type="text" name="planeaguada_empresa_id" value="<?php echo esc_attr(get_option('planeaguada_empresa_id')); ?>" /></td>
                    </tr>
                    <tr>
                        <th scope="row">API Key</th>
                        <td><input type="text" name="planeaguada_api_key" value="<?php echo esc_attr(get_option('planeaguada_api_key')); ?>" /></td>
                    </tr>
                </table>
                <?php submit_button(); ?>
            </form>

            <h2>Estado de Integración</h2>
            <p><strong>Último sync:</strong> <?php echo get_option('planeaguada_last_sync', 'Nunca'); ?></p>
            <p><strong>Total de reservas enviadas:</strong> <?php echo get_option('planeaguada_reservas_count', 0); ?></p>
            <p><strong>Total de reseñas sincronizadas:</strong> <?php echo get_option('planeaguada_reviews_count', 0); ?></p>

            <button type="button" onclick="syncNow()">Sincronizar Ahora</button>
        </div>

        <script>
        function syncNow() {
            fetch('/wp-json/planeaguada/v1/sync-now', {method: 'POST'})
                .then(response => response.json())
                .then(data => alert('Sincronización completada'))
                .catch(error => alert('Error: ' + error));
        }
        </script>
        <?php
    }

    /**
     * Registrar configuraciones
     */
    public function register_settings() {
        register_setting('planeaguada_settings', 'planeaguada_firebase_project');
        register_setting('planeaguada_settings', 'planeaguada_empresa_id');
        register_setting('planeaguada_settings', 'planeaguada_api_key');
    }
}

// Inicializar plugin
new PlaneaGuadaCRMIntegration();

// Hook de activación para crear tabla de reservas
register_activation_hook(__FILE__, 'planeaguada_create_tables');

function planeaguada_create_tables() {
    global $wpdb;

    $table_name = $wpdb->prefix . 'planeaguada_reservations';

    $charset_collate = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE $table_name (
        id mediumint(9) NOT NULL AUTO_INCREMENT,
        client_name varchar(100) NOT NULL,
        client_email varchar(100) NOT NULL,
        client_phone varchar(20) DEFAULT '',
        service varchar(100) NOT NULL,
        appointment_date datetime NOT NULL,
        status varchar(20) DEFAULT 'pendiente',
        notes text DEFAULT '',
        created_at datetime DEFAULT CURRENT_TIMESTAMP,
        updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        firebase_synced boolean DEFAULT false,
        PRIMARY KEY (id)
    ) $charset_collate;";

    require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
    dbDelta($sql);
}
?>
