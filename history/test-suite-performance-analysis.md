# Test Suite Performance Analysis
## Date: 2025-12-25

## Executive Summary

Total test suite runtime: **12 minutes 35 seconds** (755 seconds)
Total examples: 1284
Top 20 slowest examples: **131.38 seconds** (17.4% of total time)

## Top 20 Slowest Specs

| Rank | Test Description | Time (s) | File | Category |
|------|------------------|----------|------|----------|
| 1 | V1::TextsApi - search with IP type filter | 13.42 | spec/api/v1/texts_api_spec.rb:261 | API + Elasticsearch |
| 2 | V1::TextsApi - search descending pagination | 11.12 | spec/api/v1/texts_api_spec.rb:386 | API + Elasticsearch |
| 3 | V1::TextsApi - search ascending pagination (page 1) | 10.09 | spec/api/v1/texts_api_spec.rb:363 | API + Elasticsearch |
| 4 | V1::TextsApi - search ascending pagination (page 2) | 9.19 | spec/api/v1/texts_api_spec.rb:375 | API + Elasticsearch |
| 5 | CleanUpBaseUsers - cleanup unregistered users | 8.00 | spec/services/clean_up_base_users_spec.rb:21 | Service + DB |
| 6 | Anthology browse - pagination display | 6.88 | spec/system/anthology_browse_spec.rb:108 | System (browser) |
| 7 | Anthology browse - navigate to next page | 6.88 | spec/system/anthology_browse_spec.rb:116 | System (browser) |
| 8 | AdminController - missing languages | 6.35 | spec/controllers/admin_controller_spec.rb:279 | Controller + DB |
| 9 | Browse permalink - authors copy URL | 6.07 | spec/system/browse_permalink_spec.rb:34 | System (browser) |
| 10 | Browse permalink - works copy URL | 5.45 | spec/system/browse_permalink_spec.rb:98 | System (browser) |
| 11 | Tags browse - show pagination on uncheck | 5.12 | spec/system/tags_browse_spec.rb:116 | System (browser) |
| 12 | Tags browse - display all tags | 5.03 | spec/system/tags_browse_spec.rb:99 | System (browser) |
| 13 | SearchController - basic search | 4.97 | spec/controllers/search_controller_spec.rb:34 | Controller + Elasticsearch |
| 14 | Tags browse - hide pagination on check | 4.96 | spec/system/tags_browse_spec.rb:92 | System (browser) |
| 15 | SearchController - reset filters | 4.78 | spec/controllers/search_controller_spec.rb:141 | Controller + Elasticsearch |
| 16 | SearchController - manifestations filter | 4.73 | spec/controllers/search_controller_spec.rb:55 | Controller + Elasticsearch |
| 17 | SearchController - authorities filter | 4.62 | spec/controllers/search_controller_spec.rb:66 | Controller + Elasticsearch |
| 18 | SearchController - change filter selection | 4.61 | spec/controllers/search_controller_spec.rb:122 | Controller + Elasticsearch |
| 19 | V1::TextsApi - GET with epub snippet | 4.56 | spec/api/v1/texts_api_spec.rb:97 | API |
| 20 | SearchController - collections filter | 4.56 | spec/controllers/search_controller_spec.rb:88 | Controller + Elasticsearch |

## Pattern Analysis

### 1. **Elasticsearch-Heavy Tests** (75.89s total, 57.8% of top 20)
- V1::TextsApi search tests: 43.82s (ranks 1-4, 19)
- SearchController tests: 23.62s (ranks 13, 15-18, 20)
- Elasticsearch operations dominate the slowest tests

### 2. **System/Browser Tests** (35.22s total, 26.8% of top 20)
- Anthology browse: 13.76s (ranks 6-7)
- Browse permalink: 11.52s (ranks 9-10)
- Tags browse: 10.11s (ranks 11-12, 14)
- Require full browser initialization and JS execution

### 3. **Database-Intensive Tests** (14.35s total, 10.9% of top 20)
- CleanUpBaseUsers: 8.00s (rank 5)
- AdminController#missing_languages: 6.35s (rank 8)
- Large dataset creation/querying

## Top Slowest Example Groups

| Rank | Group | Avg Time | Total Time | Count | File |
|------|-------|----------|------------|-------|------|
| 1 | CleanUpBaseUsers | 16.34s | 16.34s | 1 | spec/services/clean_up_base_users_spec.rb |
| 2 | SearchController | 4.63s | 41.70s | 9 | spec/controllers/search_controller_spec.rb |
| 3 | V1::TextsApi | 4.19s | 117.43s | 28 | spec/api/v1/texts_api_spec.rb |
| 4 | Browse permalink button | 3.72s | 26.07s | 7 | spec/system/browse_permalink_spec.rb |
| 5 | Tags browse view | 3.27s | 42.52s | 13 | spec/system/tags_browse_spec.rb |

**V1::TextsApi** is the slowest group overall with **117.43 seconds total** across 28 examples.

## Proposed Improvements

### High Impact (Quick Wins)

#### 1. **Optimize Elasticsearch Test Data Setup**
**Affected specs:** V1::TextsApi, SearchController, SearchManifestations
**Current impact:** ~190+ seconds total across multiple specs
**Proposals:**
- Use shared test fixtures for Elasticsearch instead of creating fresh data for each test
- Implement `before(:all)` blocks for Elasticsearch index setup instead of `before(:each)`
- Use Elasticsearch bulk indexing API for faster data insertion
- Consider using Elasticsearch snapshots for test data restoration
- Mock Elasticsearch responses for tests that don't need real search behavior

**Expected savings:** 40-60 seconds (20-30% reduction in ES tests)

#### 2. **Parallelize System Tests with Database Cleaner Optimization**
**Affected specs:** Anthology browse, Browse permalink, Tags browse
**Current impact:** ~80 seconds total
**Proposals:**
- Use `DatabaseCleaner` transaction strategy instead of truncation for system tests where possible
- Implement shared contexts for common browser setup (e.g., `js: true` initialization)
- Use `rack_test` driver instead of full browser for tests that don't require JavaScript
- Cache Capybara server state between related tests
- Reduce `wait_time` for faster failing assertions where appropriate

**Expected savings:** 15-25 seconds (20-30% reduction in system tests)

#### 3. **Optimize Database Fixtures and Factory Usage**
**Affected specs:** CleanUpBaseUsers, AdminController, various model specs
**Current impact:** 50+ seconds
**Proposals:**
- Use `build_stubbed` instead of `create` for factories where database persistence isn't needed
- Implement database transactions for test isolation instead of truncation
- Use `FactoryBot.create_list` with optimized callbacks
- Add database indices to support common test queries
- Use `let!` sparingly and prefer lazy-loading with `let`

**Expected savings:** 10-15 seconds (15-25% reduction in DB-heavy tests)

### Medium Impact (Moderate Effort)

#### 4. **Refactor V1::TextsApi Pagination Tests**
**Affected specs:** spec/api/v1/texts_api_spec.rb (ranks 2-4)
**Current impact:** 30.40 seconds
**Proposals:**
- Consolidate pagination tests to share the same dataset
- Use smaller datasets (e.g., 10 items instead of 30) for pagination logic tests
- Extract pagination behavior to separate unit tests
- Mock Elasticsearch `search_after` responses for pure pagination logic

**Expected savings:** 15-20 seconds (50-65% reduction in these specific tests)

#### 5. **Optimize AdminController#missing_languages Test**
**Affected specs:** spec/controllers/admin_controller_spec.rb:279
**Current impact:** 6.35 seconds
**Proposals:**
- Investigate what data setup is causing the slowness
- Mock database queries if possible
- Use smaller test dataset
- Consider moving to a service object test with mocked dependencies

**Expected savings:** 3-5 seconds (50-75% reduction)

#### 6. **Batch Similar System Tests**
**Affected specs:** Browse permalink, Tags browse
**Current impact:** 37+ seconds
**Proposals:**
- Combine multiple assertions into single test scenarios where logical
- Share browser sessions across related tests with proper cleanup
- Use `aggregate_failures` to group assertions
- Implement custom helpers to reduce repetitive setup code

**Expected savings:** 8-12 seconds (20-30% reduction)

### Low Impact (Long-term Optimization)

#### 7. **Implement Test Suite Parallelization**
**Affected:** Entire test suite
**Proposals:**
- Use `parallel_tests` gem to run specs across multiple cores
- Separate slow integration tests from fast unit tests
- Run system tests on separate CI workers
- Implement test ordering optimization based on historical runtime data

**Expected savings:** 50-70% reduction in total runtime with 4-8 cores

#### 8. **Introduce Test Tags for Selective Running**
**Affected:** Development workflow
**Proposals:**
- Tag slow tests with `:slow` metadata
- Tag Elasticsearch tests with `:elasticsearch`
- Tag browser tests with `:js` or `:browser`
- Allow developers to skip slow tests during rapid development: `rspec --tag ~slow`

**Expected savings:** Not applicable to full suite, but improves development speed

#### 9. **Cache Elasticsearch Indices Between Test Runs**
**Affected:** All Elasticsearch tests
**Proposals:**
- Use Docker volumes to persist test Elasticsearch data
- Implement smart index cleanup that only deletes modified data
- Use Elasticsearch aliases to quickly swap between test datasets

**Expected savings:** 20-40 seconds in index rebuild time

## Implementation Priority

### Phase 1 (Immediate - Target: 50-80 seconds saved)
1. Optimize Elasticsearch test data setup (priority specs: V1::TextsApi, SearchController)
2. Refactor V1::TextsApi pagination tests
3. Optimize database fixtures and factory usage

### Phase 2 (Short-term - Target: 20-40 seconds saved)
4. Parallelize system tests with DatabaseCleaner optimization
5. Optimize AdminController#missing_languages test
6. Batch similar system tests

### Phase 3 (Long-term - Target: Major improvement)
7. Implement test suite parallelization
8. Introduce test tags for selective running
9. Cache Elasticsearch indices between test runs

## Risk Assessment

**Low Risk:**
- Factory optimization (`build_stubbed` vs `create`)
- Test tags for selective running
- Database transaction strategy
- Reducing test data sizes

**Medium Risk:**
- Shared Elasticsearch fixtures (may cause test interdependencies)
- Mocking Elasticsearch responses (may miss real integration issues)
- Batching system tests (may reduce test isolation)

**High Risk:**
- Test parallelization (requires significant refactoring)
- Caching Elasticsearch between runs (may cause flaky tests)

## Recommended Next Steps

1. **Review this analysis** with the team
2. **Pick 2-3 high-impact improvements** to start with
3. **Create detailed implementation plans** for chosen optimizations
4. **Implement changes incrementally** with before/after measurements
5. **Monitor for flaky tests** introduced by optimizations
6. **Document patterns** for future test writing

## Notes

- Current suite already uses transactions for most tests (DatabaseCleaner)
- Browser tests (js: true) require truncation, which is slower
- Elasticsearch tests require actual indexing, which is inherently slow
- The suite is well-maintained with only 12 pending tests
- Zero failures indicates good test health

---

**Generated by:** Claude Code
**Issue:** by-ivk
**Date:** 2025-12-25
