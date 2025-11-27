// Mock data: Loans
// Basado en el test E2E del préstamo id=6

export const loans = [
  {
    id: 6,
    client_id: 1,
    client_name: "Juan Pérez García",
    client_email: "juan.perez@example.com",
    client_phone: "+52 555 123 4567",
    associate_id: 2,
    associate_name: "María Rodríguez López",
    amount: 25000.00,
    term_biweeks: 12,
    profile_code: "standard",
    loan_reason: "Capital de trabajo para negocio familiar",
    interest_rate: 85.0,
    // Campos calculados (Sprint 6)
    biweekly_payment: 3145.83,
    total_payment: 37750.00,
    total_interest: 12750.00,
    total_commission: 29690.40,
    commission_per_payment: 2474.20,
    associate_payment: 671.63,
    // Estado y fechas
    status_id: 2,  // APPROVED
    status: "APPROVED",
    requested_at: "2025-11-01T10:30:00Z",
    approved_at: "2025-11-05T14:15:00Z",
    approved_by: 1,
    approved_by_name: "Admin Credinet",
    // Metadatos
    created_at: "2025-11-01T10:30:00Z",
    updated_at: "2025-11-05T14:15:30Z"
  },
  {
    id: 5,
    client_id: 3,
    client_name: "Ana Martínez Sánchez",
    client_email: "ana.martinez@example.com",
    client_phone: "+52 555 987 6543",
    associate_id: null,
    associate_name: null,
    amount: 15000.00,
    term_biweeks: 6,
    profile_code: "standard",
    loan_reason: "Reparación de vehículo",
    interest_rate: 85.0,
    // Campos calculados (Sprint 6)
    biweekly_payment: 3187.50,
    total_payment: 19125.00,
    total_interest: 4125.00,
    total_commission: 7425.00,
    commission_per_payment: 1237.50,
    associate_payment: 437.50,
    // Estado y fechas
    status_id: 1,  // PENDING
    status: "PENDING",
    requested_at: "2025-11-04T16:45:00Z",
    approved_at: null,
    approved_by: null,
    approved_by_name: null,
    // Metadatos
    created_at: "2025-11-04T16:45:00Z",
    updated_at: "2025-11-04T16:45:00Z"
  },
  {
    id: 4,
    client_id: 2,
    client_name: "Carlos González Ramírez",
    client_email: "carlos.gonzalez@example.com",
    client_phone: "+52 555 246 8135",
    associate_id: 3,
    associate_name: "José Luis Fernández",
    amount: 50000.00,
    term_biweeks: 24,
    profile_code: "vip",
    loan_reason: "Expansión de negocio",
    interest_rate: 75.0,
    // Campos calculados (Sprint 6)
    biweekly_payment: 3906.25,
    total_payment: 93750.00,
    total_interest: 43750.00,
    total_commission: 46875.00,
    commission_per_payment: 1953.13,
    associate_payment: 1953.12,
    // Estado y fechas
    status_id: 3,  // ACTIVE
    status: "ACTIVE",
    requested_at: "2025-10-15T09:00:00Z",
    approved_at: "2025-10-16T11:30:00Z",
    approved_by: 1,
    approved_by_name: "Admin Credinet",
    // Metadatos
    created_at: "2025-10-15T09:00:00Z",
    updated_at: "2025-10-16T11:30:00Z"
  }
];

export default loans;
