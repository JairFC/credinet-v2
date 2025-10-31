"""
Modules package - Domain modules following Clean Architecture.

Each module contains:
- domain/ - Business entities and repository interfaces
- application/ - Use cases and DTOs
- infrastructure/ - Repository implementations and external services
- routes.py - HTTP endpoints

Modules to implement (based on db/v2.0/modules/):
1. catalogs/ - 12 catalog tables (roles, statuses, levels, types)
2. loans/ - Loan management (CRUD + approval + schedule generation)
3. payments/ - Payment tracking (CRUD + status marking + audit)
4. associates/ - Associate profiles (credit tracking + statements)
5. contracts/ - Contract generation (PDF + signatures)
6. agreements/ - Payment agreements (debt consolidation)
7. cut_periods/ - Biweekly period management (closure + debt accumulation)
8. documents/ - Document management (upload + review)
"""
