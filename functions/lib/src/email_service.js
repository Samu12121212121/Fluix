"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailService = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
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