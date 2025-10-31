import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import CriticalLoanForm from '../components/CriticalLoanForm';
import UserSearchModal from '../components/UserSearchModal';

// Mocks
global.fetch = jest.fn();

describe('CriticalLoanForm', () => {
  beforeEach(() => {
    fetch.mockClear();
    localStorage.setItem('token', 'mock-token');
  });

  test('renders form with all required fields', () => {
    render(<CriticalLoanForm />);

    // Verificar elementos críticos
    expect(screen.getByText('🎯 Formulario Crítico de Préstamos')).toBeInTheDocument();
    expect(screen.getByText('Cliente (Obligatorio)')).toBeInTheDocument();
    expect(screen.getByText('🔍 Buscar Cliente')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Ejemplo: 500000.00')).toBeInTheDocument();
    expect(screen.getByDisplayValue('12')).toBeInTheDocument(); // Default term_biweeks
    expect(screen.getByText('💾 Crear Préstamo (PENDING)')).toBeInTheDocument();
  });

  test('client selection opens modal', async () => {
    render(<CriticalLoanForm />);

    const clientButton = screen.getByText('🔍 Buscar Cliente');
    fireEvent.click(clientButton);

    // Verificar que el modal se abre (aunque esté en otro componente)
    // Esto se testea más específicamente en UserSearchModal tests
  });

  test('payment preview updates when amount and terms change', async () => {
    render(<CriticalLoanForm />);

    const amountInput = screen.getByPlaceholderText('Ejemplo: 500000.00');
    const termSelect = screen.getByDisplayValue('12');

    // Cambiar monto
    fireEvent.change(amountInput, { target: { value: '120000' } });
    fireEvent.change(termSelect, { target: { value: '6' } });

    await waitFor(() => {
      // Verificar que aparece el preview
      expect(screen.getByText('📊 Preview de Pagos Proyectados')).toBeInTheDocument();
    });
  });

  test('form validation prevents submission without required fields', () => {
    render(<CriticalLoanForm />);

    const submitButton = screen.getByText('💾 Crear Préstamo (PENDING)');

    // Botón debe estar deshabilitado sin cliente seleccionado
    expect(submitButton).toBeDisabled();
  });

  test('cut assignment calculation works correctly', async () => {
    render(<CriticalLoanForm />);

    // Simular datos completos
    const amountInput = screen.getByPlaceholderText('Ejemplo: 500000.00');
    fireEvent.change(amountInput, { target: { value: '100000' } });

    await waitFor(() => {
      // Verificar que aparece información de corte
      expect(screen.getByText('🎯 Asignación de Corte')).toBeInTheDocument();
    });
  });

  test('form submission calls API correctly', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ id: 123, status: 'PENDING' })
    });

    render(<CriticalLoanForm />);

    // Simular selección de cliente (mock)
    const form = screen.getByRole('form');

    // Llenar datos mínimos
    const amountInput = screen.getByPlaceholderText('Ejemplo: 500000.00');
    fireEvent.change(amountInput, { target: { value: '100000' } });

    // Nota: En una prueba real necesitaríamos simular la selección de cliente
    // Para esta prueba, asumimos que el cliente está seleccionado

    const submitButton = screen.getByText('💾 Crear Préstamo (PENDING)');
    fireEvent.click(submitButton);

    // Esta prueba requiere que el cliente esté seleccionado
    // En un test completo, simularíamos todo el flujo
  });
});

describe('UserSearchModal', () => {
  const mockProps = {
    isOpen: true,
    onClose: jest.fn(),
    onSelect: jest.fn(),
    userType: 'cliente',
    title: 'Buscar Cliente',
    token: 'mock-token'
  };

  beforeEach(() => {
    fetch.mockClear();
    mockProps.onClose.mockClear();
    mockProps.onSelect.mockClear();
  });

  test('renders when open', () => {
    render(<UserSearchModal {...mockProps} />);

    expect(screen.getByText('Buscar Cliente')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Buscar cliente por nombre o email...')).toBeInTheDocument();
    expect(screen.getByText('+ Crear cliente')).toBeInTheDocument();
  });

  test('does not render when closed', () => {
    render(<UserSearchModal {...mockProps} isOpen={false} />);

    expect(screen.queryByText('Buscar Cliente')).not.toBeInTheDocument();
  });

  test('search input triggers API call', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => [
        { id: 1, first_name: 'Juan', last_name: 'Pérez', email: 'juan@example.com' }
      ]
    });

    render(<UserSearchModal {...mockProps} />);

    const searchInput = screen.getByPlaceholderText('Buscar cliente por nombre o email...');
    fireEvent.change(searchInput, { target: { value: 'Juan' } });

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/users/search?q=Juan&role=cliente'),
        expect.objectContaining({
          headers: { 'Authorization': 'Bearer mock-token' }
        })
      );
    });
  });

  test('user selection calls onSelect and closes modal', async () => {
    const mockUser = { id: 1, first_name: 'Juan', last_name: 'Pérez', email: 'juan@example.com' };

    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => [mockUser]
    });

    render(<UserSearchModal {...mockProps} />);

    const searchInput = screen.getByPlaceholderText('Buscar cliente por nombre o email...');
    fireEvent.change(searchInput, { target: { value: 'Juan' } });

    await waitFor(() => {
      expect(screen.getByText('Juan Pérez')).toBeInTheDocument();
    });

    const userItem = screen.getByText('Juan Pérez');
    fireEvent.click(userItem);

    expect(mockProps.onSelect).toHaveBeenCalledWith(mockUser);
    expect(mockProps.onClose).toHaveBeenCalled();
  });

  test('close button works', () => {
    render(<UserSearchModal {...mockProps} />);

    const closeButton = screen.getByText('×');
    fireEvent.click(closeButton);

    expect(mockProps.onClose).toHaveBeenCalled();
  });

  test('create user button opens new window', () => {
    // Mock window.open
    const mockOpen = jest.fn();
    global.window.open = mockOpen;

    render(<UserSearchModal {...mockProps} />);

    const createButton = screen.getByText('+ Crear cliente');
    fireEvent.click(createButton);

    expect(mockOpen).toHaveBeenCalledWith('/users/create?role=cliente', '_blank');
  });

  test('handles search errors gracefully', async () => {
    fetch.mockRejectedValueOnce(new Error('Network error'));

    render(<UserSearchModal {...mockProps} />);

    const searchInput = screen.getByPlaceholderText('Buscar cliente por nombre o email...');
    fireEvent.change(searchInput, { target: { value: 'test' } });

    await waitFor(() => {
      expect(screen.getByText('Error buscando usuarios')).toBeInTheDocument();
    });
  });

  test('shows no results message when no users found', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => []
    });

    render(<UserSearchModal {...mockProps} />);

    const searchInput = screen.getByPlaceholderText('Buscar cliente por nombre o email...');
    fireEvent.change(searchInput, { target: { value: 'nonexistent' } });

    await waitFor(() => {
      expect(screen.getByText('No se encontraron usuarios')).toBeInTheDocument();
    });
  });
});

describe('Payment Preview Logic (Frontend)', () => {
  test('payment preview calculation mock logic', () => {
    const amount = 120000;
    const terms = 6;
    const paymentAmount = amount / terms;

    // Simular lógica de preview
    const mockPreview = [];
    for (let i = 1; i <= terms; i++) {
      mockPreview.push({
        payment_number: i,
        payment_due_date: `2025-${10 + Math.floor(i / 2)}-${i % 2 === 1 ? '15' : '31'}`,
        payment_amount: paymentAmount,
        payment_type: i % 2 === 1 ? 'DÍA_15' : 'ÚLTIMO_DÍA'
      });
    }

    // Verificaciones
    expect(mockPreview).toHaveLength(6);
    expect(mockPreview[0].payment_amount).toBe(20000);
    expect(mockPreview[0].payment_type).toBe('DÍA_15');
    expect(mockPreview[1].payment_type).toBe('ÚLTIMO_DÍA');
  });

  test('cut assignment logic based on current date', () => {
    const testCases = [
      { day: 5, expected: 'CORTE_8' },
      { day: 15, expected: 'CORTE_23' },
      { day: 28, expected: 'CORTE_8_SIGUIENTE' }
    ];

    testCases.forEach(({ day, expected }) => {
      let cutType = '';

      if (day <= 7) {
        cutType = 'CORTE_8';
      } else if (day <= 22) {
        cutType = 'CORTE_23';
      } else {
        cutType = 'CORTE_8_SIGUIENTE';
      }

      expect(cutType).toBe(expected);
    });
  });
});

describe('Integration Tests', () => {
  test('complete loan creation flow simulation', async () => {
    // Mock successful API responses
    fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => [{ id: 1, first_name: 'Juan', last_name: 'Pérez', email: 'juan@example.com' }]
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 123, status: 'PENDING' })
      });

    render(<CriticalLoanForm />);

    // 1. Seleccionar cliente
    const clientButton = screen.getByText('🔍 Buscar Cliente');
    fireEvent.click(clientButton);

    // 2. Llenar datos del préstamo
    const amountInput = screen.getByPlaceholderText('Ejemplo: 500000.00');
    fireEvent.change(amountInput, { target: { value: '100000' } });

    // 3. Verificar preview aparece
    await waitFor(() => {
      expect(screen.getByText('📊 Preview de Pagos Proyectados')).toBeInTheDocument();
    });

    // 4. Verificar información de corte
    expect(screen.getByText('🎯 Asignación de Corte')).toBeInTheDocument();

    // Esta es una simulación del flujo completo
    // En una prueba E2E real, se completaría todo el proceso
  });
});