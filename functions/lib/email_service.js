"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailService = void 0;
const fs = require("fs");
const path = require("path");
/**
 * Servicio de emails con templates HTML.
 */
class EmailService {
    /**
     * Carga un template HTML y reemplaza las variables {{key}}.
     * Soporta variables simples. Para listas, pasar el HTML ya generado como string.
     */
    static buildTemplate(templateName, variables) {
        const filePath = path.join(this.templatesDir, `${templateName}.html`);
        // Fallback si no encuentra el archivo (por ejemplo si tsc no copió los assets)
        if (!fs.existsSync(filePath)) {
            console.warn(`⚠️ Template no encontrado en: ${filePath}. Usando fallback simple.`);
            return this.getFallbackTemplate(templateName, variables);
        }
        let html = fs.readFileSync(filePath, "utf-8");
        // Reemplazo simple de variables {{clave}}
        for (const [key, value] of Object.entries(variables)) {
            const regex = new RegExp(`{{${key}}}`, "g");
            html = html.replace(regex, value || "");
        }
        // Limpiar variables no reemplazadas (opcional, por si quedan {{algo}})
        // html = html.replace(/{{.*?}}/g, "");
        return html;
    }
    static getFallbackTemplate(name, variables) {
        // Un HTML básico por si falla la carga del archivo
        const list = Object.entries(variables)
            .map(([k, v]) => `<li><strong>${k}:</strong> ${v}</li>`)
            .join("");
        return `
      <html>
        <body style="font-family: sans-serif; padding: 20px;">
          <h2>${name.toUpperCase()}</h2>
          <p>Hola ${variables.clienteNombre || variables.empleadoNombre || "cliente"},</p>
          <ul>${list}</ul>
          <p>Atentamente,<br>${variables.empresaNombre || "Fluix CRM"}</p>
        </body>
      </html>
    `;
    }
}
exports.EmailService = EmailService;
EmailService.templatesDir = path.join(__dirname, "templates");
//# sourceMappingURL=email_service.js.map