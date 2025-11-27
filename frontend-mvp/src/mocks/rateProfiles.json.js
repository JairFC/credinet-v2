// Mock data: Rate Profiles
// Basado en: /db/v2.0/modules/10_rate_profiles.sql

export const rateProfiles = [
  {
    code: "standard",
    name: "Standard",
    description: "Perfil estándar para clientes regulares",
    is_active: true,
    details: [
      {
        term_biweeks: 6,
        client_rate_annual: 85.0,
        associate_rate_annual: 60.0,
        commission_rate_annual: 25.0
      },
      {
        term_biweeks: 12,
        client_rate_annual: 85.0,
        associate_rate_annual: 60.0,
        commission_rate_annual: 25.0
      },
      {
        term_biweeks: 18,
        client_rate_annual: 85.0,
        associate_rate_annual: 60.0,
        commission_rate_annual: 25.0
      },
      {
        term_biweeks: 24,
        client_rate_annual: 85.0,
        associate_rate_annual: 60.0,
        commission_rate_annual: 25.0
      }
    ]
  },
  {
    code: "vip",
    name: "VIP",
    description: "Perfil premium para clientes VIP",
    is_active: true,
    details: [
      {
        term_biweeks: 6,
        client_rate_annual: 75.0,
        associate_rate_annual: 55.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 12,
        client_rate_annual: 75.0,
        associate_rate_annual: 55.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 18,
        client_rate_annual: 75.0,
        associate_rate_annual: 55.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 24,
        client_rate_annual: 75.0,
        associate_rate_annual: 55.0,
        commission_rate_annual: 20.0
      }
    ]
  },
  {
    code: "premium",
    name: "Premium",
    description: "Perfil para clientes con historial excelente",
    is_active: true,
    details: [
      {
        term_biweeks: 6,
        client_rate_annual: 70.0,
        associate_rate_annual: 50.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 12,
        client_rate_annual: 70.0,
        associate_rate_annual: 50.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 18,
        client_rate_annual: 70.0,
        associate_rate_annual: 50.0,
        commission_rate_annual: 20.0
      },
      {
        term_biweeks: 24,
        client_rate_annual: 70.0,
        associate_rate_annual: 50.0,
        commission_rate_annual: 20.0
      }
    ]
  },
  {
    code: "basic",
    name: "Basic",
    description: "Perfil para clientes nuevos o con menor historial",
    is_active: true,
    details: [
      {
        term_biweeks: 6,
        client_rate_annual: 95.0,
        associate_rate_annual: 65.0,
        commission_rate_annual: 30.0
      },
      {
        term_biweeks: 12,
        client_rate_annual: 95.0,
        associate_rate_annual: 65.0,
        commission_rate_annual: 30.0
      }
    ]
  }
];

export default rateProfiles;
