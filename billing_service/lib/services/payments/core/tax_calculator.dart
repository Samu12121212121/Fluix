// lib/services/payments/core/tax_calculator.dart

import '../../../models/business_config.dart';
import '../../../repositories/business_config_repository.dart';
import '../interfaces/payment_event.dart';

enum VatRate {
  general(21.0),
  reduced(10.0),
  superReduced(4.0),
  exempt(0.0);

  final double percentage;
  const VatRate(this.percentage);
}

enum IrpfRate {
  none(0.0),
  professional(15.0),
  newProfessional(7.0),
  rent(19.0);

  final double percentage;
  const IrpfRate(this.percentage);
}

enum SurchargeRate {
  none(0.0),
  general(5.2),
  reduced(1.4),
  superReduced(0.5);

  final double percentage;
  const SurchargeRate(this.percentage);
}

class TaxBreakdown {
  final double        baseImponible;
  final VatRate       vatRate;
  final double        cuotaIva;
  final IrpfRate      irpfRate;
  final double        retencionIrpf;
  final SurchargeRate surchargeRate;
  final double        recargo;
  final double        importeTotal;

  const TaxBreakdown({
    required this.baseImponible,
    required this.vatRate,
    required this.cuotaIva,
    required this.irpfRate,
    required this.retencionIrpf,
    required this.surchargeRate,
    required this.recargo,
    required this.importeTotal,
  });
}

class TaxCalculator {
  final BusinessConfigRepository _config;

  TaxCalculator(this._config);

  Future<TaxBreakdown> calculate({
    required double        grossAmount,
    required String        productCode,
    required CustomerInfo? customer,
    required bool          isGrossAmount,
  }) async {
    final bizConfig = await _config.get();
    final vatRate   = await _resolveVatRate(productCode, bizConfig);

    final base  = isGrossAmount
        ? grossAmount / (1 + vatRate.percentage / 100)
        : grossAmount;
    final cuota = base * vatRate.percentage / 100;

    final irpfRate  = _resolveIrpf(customer, bizConfig);
    final retencion = base * irpfRate.percentage / 100;

    final surchargeRate = bizConfig.recargoEquivalencia
        ? _resolveSurcharge(vatRate)
        : SurchargeRate.none;
    final recargo = base * surchargeRate.percentage / 100;

    final total = base + cuota + recargo - retencion;

    return TaxBreakdown(
      baseImponible:  _r(base),
      vatRate:        vatRate,
      cuotaIva:       _r(cuota),
      irpfRate:       irpfRate,
      retencionIrpf:  _r(retencion),
      surchargeRate:  surchargeRate,
      recargo:        _r(recargo),
      importeTotal:   _r(total),
    );
  }

  Future<VatRate> _resolveVatRate(
    String productCode,
    BusinessConfig cfg,
  ) async {
    final mapping = await _config.getVatMapping(productCode);
    if (mapping == null) return VatRate.general;

    return switch (mapping as VatRateCode) {
      VatRateCode.general      => VatRate.general,
      VatRateCode.reduced      => VatRate.reduced,
      VatRateCode.superReduced => VatRate.superReduced,
      VatRateCode.exempt       => VatRate.exempt,
    };
  }

  IrpfRate _resolveIrpf(CustomerInfo? customer, BusinessConfig cfg) {
    if (!cfg.sujetaRetencionIRPF)           return IrpfRate.none;
    if (customer?.type != CustomerType.b2b) return IrpfRate.none;
    return cfg.isNuevoAutonomo
        ? IrpfRate.newProfessional
        : IrpfRate.professional;
  }

  SurchargeRate _resolveSurcharge(VatRate vat) => switch (vat) {
    VatRate.general      => SurchargeRate.general,
    VatRate.reduced      => SurchargeRate.reduced,
    VatRate.superReduced => SurchargeRate.superReduced,
    VatRate.exempt       => SurchargeRate.none,
  };

  double _r(double v) => double.parse(v.toStringAsFixed(2));
}

