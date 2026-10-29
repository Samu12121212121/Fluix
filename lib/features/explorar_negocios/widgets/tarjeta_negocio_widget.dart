import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/negocio_publico_model.dart';
import '../../reservas_cliente/pantallas/detalle_negocio_screen.dart';

class TarjetaNegocioWidget extends StatelessWidget {
  final NegocioPublico negocio;

  const TarjetaNegocioWidget({
    super.key,
    required this.negocio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleNegocioScreen(negocio: negocio),
            ),
          );
        },
        child: Container(
          height: 160,
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              _buildImageSection(),
              Expanded(
                child: _buildInfoSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      child: SizedBox(
        width: 140,
        height: 160,
        child: negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: negocio.fotoUrl!,
                fit: BoxFit.cover,
                placeholder: (_ctx, _url) => _placeholder(),
                errorWidget: (_ctx, _url, _err) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEEF2F7),
    child: const Center(child: Icon(Icons.storefront_outlined, size: 36, color: Color(0xFFCBD5E1))),
  );

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            negocio.nombre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              negocio.categoria.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if ((negocio.descripcionCorta?.isNotEmpty == true ||
              negocio.descripcion?.isNotEmpty == true)) ...[
            const SizedBox(height: 5),
            Text(
              (negocio.descripcionCorta?.isNotEmpty == true
                  ? negocio.descripcionCorta!
                  : negocio.descripcion!) ,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          if (negocio.ratingGoogle != null) _buildRating(),
          if (negocio.direccion != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    negocio.direccion!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRating() {
    return Row(
      children: [
        const Icon(
          Icons.star,
          size: 18,
          color: Color(0xFFFFB300),
        ),
        const SizedBox(width: 4),
        Text(
          negocio.ratingGoogle!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(Google)',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

