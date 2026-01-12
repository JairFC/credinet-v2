/**
 * EstadosCuentaPage - Página principal de Estados de Cuenta (Relaciones de Pago)
 * 
 * Vista jerárquica profesional:
 * 1. Timeline de períodos (navegación estilo NU Bank)
 * 2. Vista previa en tiempo real para período actual
 * 3. Tarjetas expandibles por asociado
 * 4. Modal de desglose de pagos
 * 5. Modal de registro de abonos
 * 
 * Estados del Período (Flujo):
 * PENDING → CUTOFF → COLLECTING → SETTLING → CLOSED
 * 
 * 1. PENDING    - Períodos futuros con pagos pre-asignados
 * 3. CUTOFF     - BORRADOR: Corte automático, statements en revisión
 * 4. COLLECTING - EN COBRO: Cierre manual, fase de cobro a asociados
 * 6. SETTLING   - LIQUIDACIÓN: Revisión de deuda antes de cierre definitivo
 * 5. CLOSED     - Período archivado definitivamente
 * 
 * (ACTIVE=2 está deprecado - no se usa)
 */

import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import apiClient from '@/shared/api/apiClient';
import PeriodoTimelineV2 from '../components/PeriodoTimelineV2';
import RelacionAsociadoCard from '../components/RelacionAsociadoCard';
import RegistrarAbonoModal from '../components/RegistrarAbonoModal';
import './EstadosCuentaPage.css';

// Configuración de estados de período
// Flujo: PENDING → CUTOFF → COLLECTING → SETTLING → CLOSED
const PERIOD_STATUS = {
  1: 'PENDING',
  2: 'ACTIVE',      // DEPRECADO
  3: 'CUTOFF',      // Borrador
  4: 'COLLECTING',  // En cobro
  5: 'CLOSED',
  6: 'SETTLING'     // Liquidación
};

// Estados de statements por asociado
// Flujo: DRAFT → COLLECTING → SETTLING → CLOSED
const STATEMENT_STATUS = {
  6: 'DRAFT',       // Borrador (período en CUTOFF)
  7: 'COLLECTING',  // En cobro (período en COLLECTING)
  9: 'SETTLING',    // Liquidación (período en SETTLING)
  10: 'CLOSED',     // Cerrado (período CLOSED)
  3: 'PAID',        // Pagado completamente (legacy)
  4: 'PARTIAL',     // Pago parcial recibido (legacy)
  5: 'OVERDUE',     // Vencido sin pago completo (legacy)
  8: 'ABSORBED'     // Deuda transferida (legacy)
};

// Formatea moneda
const formatMoney = (amount) => {
  if (amount === null || amount === undefined) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(amount);
};

export default function EstadosCuentaPage() {
  const navigate = useNavigate();

  // Estados principales
  const [periods, setPeriods] = useState([]);
  const [selectedPeriod, setSelectedPeriod] = useState(null);
  const [statements, setStatements] = useState([]);
  const [previewPayments, setPreviewPayments] = useState([]);

  // Estados de UI
  const [loading, setLoading] = useState(true);
  const [loadingStatements, setLoadingStatements] = useState(false);
  const [expandedCard, setExpandedCard] = useState(null);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterMode, setFilterMode] = useState('with-payments'); // Default: solo con pagos

  // Paginación
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5; // Paginación más agresiva

  // Modal de abono (el de desglose ahora es una página)
  const [abonoModalOpen, setAbonoModalOpen] = useState(false);
  const [selectedStatementForAbono, setSelectedStatementForAbono] = useState(null);

  // Cargar períodos al montar
  useEffect(() => {
    loadPeriods();
  }, []);

  // Cargar statements cuando cambia el período seleccionado
  // Siempre cargar con include_all=true para tener conteos correctos
  useEffect(() => {
    if (selectedPeriod) {
      loadPeriodData(selectedPeriod, true);  // Siempre incluir todos
    }
  }, [selectedPeriod?.id]);

  // Función para cargar períodos
  const loadPeriods = async () => {
    try {
      setLoading(true);
      
      // Cargar períodos en lotes para obtener todos (hay ~288)
      const allPeriods = [];
      let offset = 0;
      const batchSize = 100;
      let hasMore = true;
      
      while (hasMore) {
        const response = await apiClient.get('/api/v1/cut-periods', {
          params: { limit: batchSize, offset }
        });
        const batch = response.data.items || [];
        allPeriods.push(...batch);
        offset += batchSize;
        hasMore = batch.length === batchSize;
        
        // Límite de seguridad
        if (offset > 500) break;
      }

      // Añadir campos derivados para el timeline y ordenar por fecha descendente
      const enrichedPeriods = allPeriods
        .map(p => ({
          ...p,
          period_code: p.cut_code,
          start_date: p.period_start_date,
          end_date: p.period_end_date
        }))
        .sort((a, b) => new Date(b.period_start_date) - new Date(a.period_start_date));

      setPeriods(enrichedPeriods);

      // Seleccionar período por prioridad:
      // 1. SETTLING (LIQUIDACIÓN) - deuda pendiente de cierre
      // 2. COLLECTING (EN COBRO) - donde se trabaja normalmente
      // 3. CUTOFF (BORRADOR) - pendiente de cerrar corte
      // 4. Período más reciente con actividad real (statements o pagos > 0)
      // 5. Período actual según fecha del sistema
      const today = new Date().toISOString().split('T')[0];
      
      const settlingPeriod = enrichedPeriods.find(p => p.status_id === 6);   // SETTLING
      const collectingPeriod = enrichedPeriods.find(p => p.status_id === 4); // COLLECTING
      const cutoffPeriod = enrichedPeriods.find(p => p.status_id === 3);     // CUTOFF
      const withActivityPeriod = enrichedPeriods.find(p => 
        p.statements_count > 0 || p.payment_count > 0
      );
      // Período que contiene la fecha actual
      const currentDatePeriod = enrichedPeriods.find(p => 
        p.period_start_date <= today && p.period_end_date >= today
      );

      if (settlingPeriod) {
        setSelectedPeriod(settlingPeriod);
      } else if (collectingPeriod) {
        setSelectedPeriod(collectingPeriod);
      } else if (cutoffPeriod) {
        setSelectedPeriod(cutoffPeriod);
      } else if (withActivityPeriod) {
        setSelectedPeriod(withActivityPeriod);
      } else if (currentDatePeriod) {
        setSelectedPeriod(currentDatePeriod);
      } else if (enrichedPeriods.length > 0) {
        setSelectedPeriod(enrichedPeriods[0]);
      }
    } catch (err) {
      console.error('Error loading periods:', err);
      setError('Error al cargar los períodos');
    } finally {
      setLoading(false);
    }
  };

  // Función para cargar datos del período (statements o preview)
  const loadPeriodData = async (period, includeAllAssociates = false) => {
    if (!period) return;

    try {
      setLoadingStatements(true);
      setError(null);

      const periodStatus = PERIOD_STATUS[period.status_id];

      // Preview mode: PENDING, CUTOFF (períodos sin cierre manual - statements en borrador)
      // Statements finales: COLLECTING, SETTLING, CLOSED (períodos con cierre ejecutado)
      if (periodStatus === 'PENDING' || periodStatus === 'CUTOFF') {
        // Para períodos sin cierre: cargar preview de pagos
        await loadPreviewPayments(period.id);
      } else {
        // Para períodos con cierre (COLLECTING, SETTLING, CLOSED): cargar statements generados
        // Incluir todos los asociados si se requiere filtrar "sin pagos"
        await loadStatements(period.id, includeAllAssociates);
      }
    } catch (err) {
      console.error('Error loading period data:', err);
      setError('Error al cargar datos del período');
    } finally {
      setLoadingStatements(false);
    }
  };

  // Cargar preview de pagos (para períodos PENDING, ACTIVE, CUTOFF)
  const loadPreviewPayments = async (periodId) => {
    try {
      // Usar el nuevo endpoint de preview de pagos por período
      // include_all_associates=true para mostrar también asociados sin pagos
      const response = await apiClient.get(`/api/v1/cut-periods/${periodId}/payments-preview`, {
        params: { include_all_associates: true }
      });

      if (response.data.success) {
        const previewData = response.data.data || [];

        // Transformar a formato compatible con las cards
        const transformedStatements = previewData.map(assoc => ({
          associate_id: assoc.associate_id,
          associate_name: assoc.associate_name,
          associate_code: `A${String(assoc.associate_id).padStart(4, '0')}`,
          total_collected: assoc.total_collected,
          total_commission: assoc.total_commission,
          total_to_credicuenta: assoc.total_to_credicuenta,
          total_paid: assoc.total_paid,
          balance: assoc.balance,
          late_fee: 0,
          status_id: 6, // DRAFT (preview/borrador)
          payment_count: assoc.payment_count,
          payments: assoc.payments,
          has_payments: assoc.has_payments,
          isPreview: true
        }));

        setStatements(transformedStatements);
        setPreviewPayments(previewData);
      } else {
        setPreviewPayments([]);
        setStatements([]);
      }

    } catch (err) {
      console.error('Error loading preview payments:', err);
      setPreviewPayments([]);
      setStatements([]);
    }
  };

  // Cargar statements generados (para períodos cerrados)
  // include_all agrega asociados sin pagos cuando el filtro lo requiere
  const loadStatements = async (periodId, includeAll = false) => {
    try {
      const url = `/api/v1/cut-periods/${periodId}/statements${includeAll ? '?include_all_associates=true' : ''}`;
      const response = await apiClient.get(url);

      const statementsData = response.data.data || [];

      // Enriquecer statements con campos necesarios para las cards
      // El backend ahora envía los campos correctos:
      // - total_to_credicuenta: Lo que el asociado debe pagar a CrediCuenta
      // - commission_earned: La comisión que gana el asociado
      const enrichedStatements = statementsData.map(s => {
        return {
          id: s.id,
          associate_id: s.associate_id,
          associate_name: s.associate_name,
          associate_code: `A${String(s.associate_id).padStart(4, '0')}`,
          total_collected: s.total_amount_collected,
          total_commission: s.commission_earned || 0,  // Comisión ganada por el asociado
          total_to_credicuenta: s.total_to_credicuenta, // Lo que paga el asociado a CrediCuenta
          total_paid: s.paid_amount || 0,
          balance: (s.total_to_credicuenta || 0) - (s.paid_amount || 0),
          late_fee: s.late_fee_amount || 0,
          status_id: s.status_id,
          payment_count: s.total_payments_count || 0,
          statement_number: s.statement_number,
          due_date: s.due_date,
          generated_date: s.generated_date,
          has_payments: s.has_payments !== false  // Del backend
        };
      });

      setStatements(enrichedStatements);
      setPreviewPayments([]);

    } catch (err) {
      console.error('Error loading statements:', err);
      setStatements([]);
    }
  };

  // Agrupar pagos por asociado (para vista previa)
  const groupPaymentsByAssociate = (payments) => {
    const groups = {};

    payments.forEach(payment => {
      const associateId = payment.associate_id;
      if (!groups[associateId]) {
        groups[associateId] = {
          associate_id: associateId,
          associate_name: payment.associate_name || `Asociado #${associateId}`,
          associate_code: `A${String(associateId).padStart(4, '0')}`,
          total_collected: 0,
          total_commission: 0,
          total_to_credicuenta: 0,
          total_paid: 0,
          balance: 0,
          late_fee: 0,
          status_id: 6, // DRAFT (preview/borrador)
          payment_count: 0,
          payments: [],
          isPreview: true
        };
      }

      const expected = payment.expected_amount || 0;
      const commission = payment.commission_amount || 0;
      const associatePayment = payment.associate_payment || (expected - commission);

      groups[associateId].total_collected += expected;
      groups[associateId].total_commission += commission;
      groups[associateId].total_to_credicuenta += associatePayment;
      groups[associateId].payment_count += 1;
      groups[associateId].balance = groups[associateId].total_to_credicuenta;
      groups[associateId].payments.push(payment);
    });

    return Object.values(groups).sort((a, b) =>
      (a.associate_name || '').localeCompare(b.associate_name || '')
    );
  };

  // Filtrar statements según búsqueda y filtro
  const filteredStatements = useMemo(() => {
    let filtered = statements;

    // Filtrar por término de búsqueda
    if (searchTerm.trim()) {
      const term = searchTerm.toLowerCase().trim();
      filtered = filtered.filter(s =>
        (s.associate_name || '').toLowerCase().includes(term) ||
        (s.associate_code || '').toLowerCase().includes(term)
      );
    }

    // Filtrar por modo (con/sin pagos)
    if (filterMode === 'with-payments') {
      filtered = filtered.filter(s => s.has_payments !== false && s.payment_count > 0);
    } else if (filterMode === 'without-payments') {
      filtered = filtered.filter(s => s.has_payments === false || s.payment_count === 0);
    }

    return filtered;
  }, [statements, searchTerm, filterMode]);

  // Resetear página cuando cambie filtro o búsqueda
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, filterMode, selectedPeriod?.id]);

  // Datos de paginación
  const paginationData = useMemo(() => {
    const totalItems = filteredStatements.length;
    const totalPages = Math.ceil(totalItems / itemsPerPage);
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
    const paginatedStatements = filteredStatements.slice(startIndex, endIndex);

    return {
      paginatedStatements,
      totalItems,
      totalPages,
      startIndex: startIndex + 1,
      endIndex,
      hasNextPage: currentPage < totalPages,
      hasPrevPage: currentPage > 1
    };
  }, [filteredStatements, currentPage, itemsPerPage]);

  // Conteos para filtros
  const filterCounts = useMemo(() => {
    const withPayments = statements.filter(s => s.has_payments !== false && s.payment_count > 0).length;
    const withoutPayments = statements.filter(s => s.has_payments === false || s.payment_count === 0).length;
    return { all: statements.length, withPayments, withoutPayments };
  }, [statements]);

  // Estadísticas del período seleccionado (solo de los que tienen pagos)
  const periodStats = useMemo(() => {
    // Solo calcular stats de statements con pagos
    const statementsWithPayments = statements.filter(s => s.has_payments !== false && s.payment_count > 0);

    if (!statementsWithPayments || statementsWithPayments.length === 0) {
      return {
        totalCollected: 0,
        totalCommission: 0,
        totalToCredicuenta: 0,
        totalPaid: 0,
        totalBalance: 0,
        associateCount: 0,
        associateCountTotal: statements.length,
        paymentCount: 0,
        paidStatements: 0,
        pendingStatements: 0,
        statementCount: statements.length  // Para el timeline
      };
    }

    const stats = statementsWithPayments.reduce((acc, s) => ({
      totalCollected: acc.totalCollected + (s.total_collected || 0),
      totalCommission: acc.totalCommission + (s.total_commission || 0),
      totalToCredicuenta: acc.totalToCredicuenta + (s.total_to_credicuenta || 0),
      totalPaid: acc.totalPaid + (s.total_paid || 0),
      totalBalance: acc.totalBalance + (s.balance || 0),
      associateCount: acc.associateCount + 1,
      paymentCount: acc.paymentCount + (s.payment_count || 0),
      paidStatements: acc.paidStatements + (s.status_id === 3 ? 1 : 0),
      pendingStatements: acc.pendingStatements + (s.status_id !== 3 ? 1 : 0)
    }), {
      totalCollected: 0,
      totalCommission: 0,
      totalToCredicuenta: 0,
      totalPaid: 0,
      totalBalance: 0,
      associateCount: 0,
      paymentCount: 0,
      paidStatements: 0,
      pendingStatements: 0
    });

    return { 
      ...stats, 
      associateCountTotal: statements.length,
      statementCount: statementsWithPayments.length  // Para el timeline
    };
  }, [statements]);

  // Handlers
  const handleViewPayments = async (statement) => {
    // Navegar a la página de detalles del statement
    navigate(`/estados-cuenta/${statement.id}`, {
      state: {
        statement,
        periodInfo: selectedPeriod
      }
    });
  };

  const handleMakePayment = (statement) => {
    setSelectedStatementForAbono(statement);
    setAbonoModalOpen(true);
  };

  // Handler para ver todos los pagos desde la tarjeta
  const handleViewAllPayments = (statement, payments, periodInfo) => {
    // Navegar a la página de detalles
    navigate(`/estados-cuenta/${statement.id}`, {
      state: {
        statement,
        periodInfo: periodInfo || selectedPeriod
      }
    });
  };

  const handleGeneratePDF = (statement) => {
    // TODO: Implementar generación de PDF
    console.log('Generate PDF for statement:', statement);
    alert('🚧 Generación de PDF en desarrollo');
  };

  const handleToggleExpand = (statementId) => {
    setExpandedCard(expandedCard === statementId ? null : statementId);
  };

  // ========================================
  // HANDLERS DE ACCIONES DEL PERÍODO
  // ========================================

  // CERRAR CORTE: CUTOFF → COLLECTING
  // Genera statements finalizados desde el borrador
  const handleCerrarCorte = async () => {
    if (!selectedPeriod || PERIOD_STATUS[selectedPeriod.status_id] !== 'CUTOFF') {
      return;
    }

    if (!window.confirm(
      `¿Estás seguro de CERRAR CORTE del período ${selectedPeriod.cut_code}?\n\n` +
      `Esta acción:\n` +
      `• Generará los estados de cuenta oficiales\n` +
      `• Los statements pasarán a EN COBRO\n` +
      `• El período pasará a EN COBRO\n\n` +
      `Esta acción NO se puede deshacer.`
    )) {
      return;
    }

    try {
      setLoading(true);
      // TODO: Implementar endpoint de cierre de corte
      // await apiClient.post(`/api/v1/cut-periods/${selectedPeriod.id}/close-cutoff`);

      // Por ahora, actualizar estado directamente
      await apiClient.patch(`/api/v1/cut-periods/${selectedPeriod.id}`, {
        status_id: 4 // COLLECTING
      });

      alert(`✅ Corte cerrado exitosamente.\n\nEl período ${selectedPeriod.cut_code} está ahora EN COBRO.`);

      // Recargar datos
      await loadPeriods();
    } catch (err) {
      console.error('Error al cerrar corte:', err);
      alert('❌ Error al cerrar el corte. Por favor intenta de nuevo.');
    } finally {
      setLoading(false);
    }
  };

  // PASAR A LIQUIDACIÓN: COLLECTING → SETTLING
  // Termina la fase de cobro y prepara para cierre
  const handlePasarLiquidacion = async () => {
    if (!selectedPeriod || PERIOD_STATUS[selectedPeriod.status_id] !== 'COLLECTING') {
      return;
    }

    // Calcular estadísticas de deuda pendiente
    const totalPendiente = periodStats.totalToCredicuenta - periodStats.totalPaid;
    const asociadosConDeuda = statements.filter(s => {
      const adeudo = (s.total_to_credicuenta || 0) + (s.late_fee || 0) - (s.total_paid || 0);
      return adeudo > 0;
    }).length;

    if (!window.confirm(
      `¿Estás seguro de PASAR A LIQUIDACIÓN el período ${selectedPeriod.cut_code}?\n\n` +
      `Resumen actual:\n` +
      `• Deuda pendiente total: $${totalPendiente.toFixed(2)}\n` +
      `• Asociados con deuda: ${asociadosConDeuda}\n\n` +
      `Esta acción:\n` +
      `• Terminará la fase de cobro activa\n` +
      `• Los statements no pagados pasarán a VENCIDO\n` +
      `• El período pasará a modo LIQUIDACIÓN\n\n` +
      `Podrás seguir registrando pagos antes del cierre definitivo.`
    )) {
      return;
    }

    try {
      setLoading(true);

      // Actualizar estado del período a SETTLING (6)
      await apiClient.patch(`/api/v1/cut-periods/${selectedPeriod.id}`, {
        status_id: 6 // SETTLING
      });

      alert(
        `✅ Período pasado a LIQUIDACIÓN.\n\n` +
        `El período ${selectedPeriod.cut_code} está ahora en fase de liquidación.\n` +
        `Puedes continuar registrando abonos antes del cierre definitivo.`
      );

      // Recargar datos
      await loadPeriods();
    } catch (err) {
      console.error('Error al pasar a liquidación:', err);
      alert('❌ Error al pasar a liquidación. Por favor intenta de nuevo.');
    } finally {
      setLoading(false);
    }
  };

  // CERRAR DEFINITIVO: SETTLING → CLOSED
  // Transfiere deuda pendiente y archiva el período
  const handleCerrarDefinitivo = async () => {
    if (!selectedPeriod || PERIOD_STATUS[selectedPeriod.status_id] !== 'SETTLING') {
      return;
    }

    if (!window.confirm(
      `¿Estás seguro de CERRAR DEFINITIVAMENTE el período ${selectedPeriod.cut_code}?\n\n` +
      `Esta acción:\n` +
      `• Transferirá la deuda pendiente al balance de cada asociado\n` +
      `• Los statements pasarán a ABSORBIDOS\n` +
      `• El período quedará en CERRADO (solo lectura)\n\n` +
      `Esta acción NO se puede deshacer.`
    )) {
      return;
    }

    try {
      setLoading(true);
      // TODO: Implementar endpoint de cierre definitivo
      // await apiClient.post(`/api/v1/cut-periods/${selectedPeriod.id}/close-final`);

      // Por ahora, actualizar estado directamente
      await apiClient.patch(`/api/v1/cut-periods/${selectedPeriod.id}`, {
        status_id: 5 // CLOSED
      });

      alert(`✅ Período cerrado definitivamente.\n\nEl período ${selectedPeriod.cut_code} ha sido archivado.`);

      // Recargar datos
      await loadPeriods();
    } catch (err) {
      console.error('Error al cerrar período:', err);
      alert('❌ Error al cerrar el período. Por favor intenta de nuevo.');
    } finally {
      setLoading(false);
    }
  };

  // ========================================
  // 🧪 BOTÓN DE TEST - SOLO PARA DEMO
  // TODO: Eliminar después de la presentación
  // ========================================
  const handleRevertirEstado = async () => {
    if (!selectedPeriod) return;

    const estadosDisponibles = [
      { id: 1, name: 'PENDING', label: '📋 Pendiente' },
      { id: 3, name: 'CUTOFF', label: '✂️ Borrador' },
      { id: 4, name: 'COLLECTING', label: '💰 En Cobro' },
      { id: 6, name: 'SETTLING', label: '⚖️ Liquidación' },
      { id: 5, name: 'CLOSED', label: '✅ Cerrado' }
    ];

    const opciones = estadosDisponibles
      .map((e, i) => `${i + 1}. ${e.label}`)
      .join('\n');

    const seleccion = window.prompt(
      `🧪 MODO TEST - Cambiar estado de ${selectedPeriod.cut_code}\n\n` +
      `Estado actual: ${PERIOD_STATUS[selectedPeriod.status_id]}\n\n` +
      `Selecciona el nuevo estado:\n${opciones}\n\n` +
      `Ingresa el número (1-5):`,
      '2'
    );

    if (!seleccion) return;

    const indice = parseInt(seleccion) - 1;
    if (isNaN(indice) || indice < 0 || indice >= estadosDisponibles.length) {
      alert('❌ Opción inválida');
      return;
    }

    const nuevoEstado = estadosDisponibles[indice];

    try {
      setLoading(true);
      // 🧪 TEST: Usar ?force=true para saltarse validación de transiciones
      await apiClient.patch(`/api/v1/cut-periods/${selectedPeriod.id}?force=true`, {
        status_id: nuevoEstado.id
      });

      alert(`✅ Estado cambiado a: ${nuevoEstado.label}`);
      await loadPeriods();
    } catch (err) {
      console.error('Error:', err);
      alert('❌ Error al cambiar estado');
    } finally {
      setLoading(false);
    }
  };

  // Obtener el estado actual del período para mostrar acciones correctas
  const currentPeriodStatus = selectedPeriod ? PERIOD_STATUS[selectedPeriod.status_id] : null;

  // Determinar si estamos en modo preview (sin statements finales)
  // Preview: PENDING, CUTOFF (borradores)
  // Statements finales: COLLECTING, SETTLING, CLOSED
  const isPreviewMode = selectedPeriod &&
    ['PENDING', 'CUTOFF'].includes(PERIOD_STATUS[selectedPeriod.status_id]);

  if (loading) {
    return (
      <div className="estados-cuenta-page">
        <div className="page-loading">
          <div className="spinner-large"></div>
          <p>Cargando estados de cuenta...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="estados-cuenta-page">
      {/* Timeline de períodos futurista - Incluye header */}
      <section className="timeline-section">
        <PeriodoTimelineV2
          periods={periods}
          selectedPeriod={selectedPeriod}
          onSelectPeriod={setSelectedPeriod}
          loading={loading}
          periodStats={periodStats}
        />
      </section>

      {/* Banner de preview si aplica */}
      {isPreviewMode && (
        <div className="preview-banner">
          <div className="banner-content">
            <span className="banner-icon">👁️</span>
            <div className="banner-text">
              <strong>Vista Previa en Tiempo Real</strong>
              <p>
                Estos son los pagos esperados para el período actual.
                Los estados de cuenta oficiales se generarán automáticamente al cierre del período.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Barra de Acciones del Período */}
      {selectedPeriod && (
        <section className="period-actions-section">
          <div className="actions-container">
            {/* Info del estado actual */}
            <div className="status-info">
              <span className="status-label">Estado actual:</span>
              <span className={`status-badge status-${currentPeriodStatus?.toLowerCase()}`}>
                {currentPeriodStatus === 'CUTOFF' && '✂️ BORRADOR'}
                {currentPeriodStatus === 'COLLECTING' && '💰 EN COBRO'}
                {currentPeriodStatus === 'SETTLING' && '⚖️ LIQUIDACIÓN'}
                {currentPeriodStatus === 'CLOSED' && '✅ CERRADO'}
                {currentPeriodStatus === 'PENDING' && '📋 PENDIENTE'}
              </span>
            </div>

            {/* Botones de acción según estado */}
            <div className="action-buttons">
              {/* CUTOFF: Mostrar botón CERRAR CORTE */}
              {currentPeriodStatus === 'CUTOFF' && (
                <button
                  className="action-btn primary"
                  onClick={handleCerrarCorte}
                  disabled={loading}
                >
                  <span className="btn-icon">✂️</span>
                  <span className="btn-text">Cerrar Corte</span>
                  <span className="btn-hint">Genera estados de cuenta oficiales</span>
                </button>
              )}

              {/* COLLECTING: Mostrar botón PASAR A LIQUIDACIÓN */}
              {currentPeriodStatus === 'COLLECTING' && (
                <button
                  className="action-btn warning"
                  onClick={handlePasarLiquidacion}
                  disabled={loading}
                >
                  <span className="btn-icon">⚖️</span>
                  <span className="btn-text">Pasar a Liquidación</span>
                  <span className="btn-hint">Termina cobro y prepara cierre</span>
                </button>
              )}

              {/* SETTLING: Mostrar botón CERRAR DEFINITIVO */}
              {currentPeriodStatus === 'SETTLING' && (
                <button
                  className="action-btn danger"
                  onClick={handleCerrarDefinitivo}
                  disabled={loading}
                >
                  <span className="btn-icon">🔒</span>
                  <span className="btn-text">Cerrar Definitivo</span>
                  <span className="btn-hint">Transfiere deuda y archiva período</span>
                </button>
              )}

              {/* CLOSED: Solo lectura */}
              {currentPeriodStatus === 'CLOSED' && (
                <div className="readonly-notice">
                  <span className="notice-icon">🔒</span>
                  <span className="notice-text">Período archivado - Solo lectura</span>
                </div>
              )}

              {/* 🧪 BOTÓN DE TEST - ELIMINAR DESPUÉS DE PRESENTACIÓN */}
              <button
                className="action-btn test-btn"
                onClick={handleRevertirEstado}
                disabled={loading}
                title="🧪 Solo para demo - Se eliminará después"
              >
                <span className="btn-icon">🧪</span>
                <span className="btn-text">Test: Cambiar Estado</span>
                <span className="btn-hint">⚠️ Solo demo - Eliminar después</span>
              </button>
            </div>
          </div>
        </section>
      )}

      {/* Estadísticas del período */}
      <section className="stats-section">
        <div className="stats-grid">
          <div className="stat-card primary">
            <div className="stat-icon">💰</div>
            <div className="stat-content">
              <span className="stat-label">Total Esperado</span>
              <span className="stat-value">{formatMoney(periodStats.totalCollected)}</span>
            </div>
          </div>

          <div className="stat-card success">
            <div className="stat-icon">🏷️</div>
            <div className="stat-content">
              <span className="stat-label">Comisiones</span>
              <span className="stat-value">{formatMoney(periodStats.totalCommission)}</span>
            </div>
          </div>

          <div className="stat-card info">
            <div className="stat-icon">🏦</div>
            <div className="stat-content">
              <span className="stat-label">A CrediCuenta</span>
              <span className="stat-value">{formatMoney(periodStats.totalToCredicuenta)}</span>
            </div>
          </div>

          <div className="stat-card warning">
            <div className="stat-icon">💳</div>
            <div className="stat-content">
              <span className="stat-label">Abonado</span>
              <span className="stat-value">{formatMoney(periodStats.totalPaid)}</span>
            </div>
          </div>

          <div className={`stat-card ${periodStats.totalBalance > 0 ? 'danger' : 'success'}`}>
            <div className="stat-icon">📊</div>
            <div className="stat-content">
              <span className="stat-label">Saldo Pendiente</span>
              <span className="stat-value">{formatMoney(periodStats.totalBalance)}</span>
            </div>
          </div>

          <div className="stat-card neutral">
            <div className="stat-icon">👥</div>
            <div className="stat-content">
              <span className="stat-label">Asociados</span>
              <span className="stat-value">{periodStats.associateCount}</span>
            </div>
          </div>
        </div>
      </section>

      {/* Error message */}
      {error && (
        <div className="error-banner">
          <span>⚠️</span> {error}
        </div>
      )}

      {/* Lista de Relaciones por Asociado */}
      <section className="statements-section">
        <div className="section-header">
          <h2>
            <span>👥</span>
            Relaciones por Asociado
          </h2>
          <span className="section-count">
            {filterCounts.withPayments} con pagos
            {filterCounts.withoutPayments > 0 && ` • ${filterCounts.withoutPayments} sin pagos`}
          </span>
        </div>

        {/* Barra de búsqueda y filtros */}
        <div className="search-filter-bar">
          <div className="search-box">
            <span className="search-icon">🔍</span>
            <input
              type="text"
              placeholder="Buscar asociado por nombre o código..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="search-input"
            />
            {searchTerm && (
              <button className="clear-search" onClick={() => setSearchTerm('')}>×</button>
            )}
          </div>
          <div className="filter-buttons">
            <button
              className={`filter-btn ${filterMode === 'all' ? 'active' : ''}`}
              onClick={() => setFilterMode('all')}
            >
              Todos ({filterCounts.all})
            </button>
            <button
              className={`filter-btn ${filterMode === 'with-payments' ? 'active' : ''}`}
              onClick={() => setFilterMode('with-payments')}
            >
              Con pagos ({filterCounts.withPayments})
            </button>
            {filterCounts.withoutPayments > 0 && (
              <button
                className={`filter-btn ${filterMode === 'without-payments' ? 'active' : ''}`}
                onClick={() => setFilterMode('without-payments')}
              >
                Sin pagos ({filterCounts.withoutPayments})
              </button>
            )}
          </div>
        </div>

        {loadingStatements ? (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Cargando relaciones...</p>
          </div>
        ) : filteredStatements.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">📭</span>
            <h3>
              {searchTerm
                ? 'Sin resultados'
                : filterMode === 'without-payments'
                  ? 'Todos los asociados tienen pagos'
                  : 'Sin relaciones de pago'
              }
            </h3>
            <p>
              {searchTerm
                ? `No se encontraron asociados que coincidan con "${searchTerm}"`
                : isPreviewMode
                  ? 'No hay pagos programados para este período todavía.'
                  : 'No se encontraron estados de cuenta para este período.'
              }
            </p>
            {searchTerm && (
              <button className="btn-clear-filter" onClick={() => setSearchTerm('')}>
                Limpiar búsqueda
              </button>
            )}
          </div>
        ) : (
          <>
            {/* Lista de statements paginada */}
            <div className="statements-list">
              {paginationData.paginatedStatements.map((statement) => (
                <RelacionAsociadoCard
                  key={statement.associate_id || statement.id}
                  statement={statement}
                  onViewPayments={handleViewPayments}
                  onMakePayment={handleMakePayment}
                  isPreview={statement.isPreview}
                  hasPayments={statement.has_payments !== false && statement.payment_count > 0}
                />
              ))}
            </div>

            {/* Controles de paginación */}
            {paginationData.totalPages > 1 && (
              <div className="pagination-controls">
                <div className="pagination-info">
                  Mostrando {paginationData.startIndex}-{paginationData.endIndex} de {paginationData.totalItems} asociados
                </div>
                <div className="pagination-buttons">
                  <button
                    className="pagination-btn pagination-btn-icon"
                    onClick={() => setCurrentPage(1)}
                    disabled={!paginationData.hasPrevPage}
                    title="Primera página"
                  >
                    «
                  </button>
                  <button
                    className="pagination-btn"
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={!paginationData.hasPrevPage}
                    title="Página anterior"
                  >
                    ‹ Anterior
                  </button>
                  <span className="pagination-current">
                    Página {currentPage} de {paginationData.totalPages}
                  </span>
                  <button
                    className="pagination-btn"
                    onClick={() => setCurrentPage(p => Math.min(paginationData.totalPages, p + 1))}
                    disabled={!paginationData.hasNextPage}
                    title="Página siguiente"
                  >
                    Siguiente ›
                  </button>
                  <button
                    className="pagination-btn pagination-btn-icon"
                    onClick={() => setCurrentPage(paginationData.totalPages)}
                    disabled={!paginationData.hasNextPage}
                    title="Última página"
                  >
                    »
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </section>

      {/* Modal de Registro de Abono */}
      <RegistrarAbonoModal
        isOpen={abonoModalOpen}
        onClose={() => {
          setAbonoModalOpen(false);
          setSelectedStatementForAbono(null);
        }}
        statement={selectedStatementForAbono}
        periodInfo={selectedPeriod}
        onSuccess={(data) => {
          // Recargar los statements para reflejar el pago
          if (selectedPeriod) {
            loadPeriodData(selectedPeriod);
          }
        }}
      />
    </div>
  );
}
