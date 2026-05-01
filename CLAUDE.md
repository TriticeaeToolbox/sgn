# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Breedbase/SGN (Sol Genomics Network) codebase - a comprehensive breeding management system built on:
- **Backend**: Perl with Catalyst MVC framework
- **Frontend**: HTML::Mason templates + JavaScript (webpack bundled)
- **Database**: PostgreSQL with Chado schema extensions
- **Testing**: Perl Test::More, Selenium2 for integration tests
- **Analytics**: R scripts for statistical analysis

The system powers multiple breeding databases including Cassavabase, Musabase, Sweetpotatobase, Yambase, and SGN.

## Development Commands

### Running Tests

```bash
# Run unit tests (no database required)
prove --recurse t/unit

# Run unit_fixture tests (requires fixture database)
perl t/test_fixture.pl t/unit_fixture

# Run unit_mech tests (Catalyst controller tests)
perl t/test_fixture.pl t/unit_mech

# Run selenium integration tests
perl t/test_fixture.pl t/selenium2/

# Run a single test file
perl t/test_fixture.pl --logfile logfile.testserver.txt t/unit_mech/AJAX/BrAPI_v2.t 2>test.results.txt
```

The test fixture script (`t/test_fixture.pl`) starts a test server and loads the fixture database. Tests run against the `sgn_test.conf` configuration.

### JavaScript Build

```bash
cd js/

# Build JavaScript bundles
npm run build

# Build in watch mode for development
npm run build-watch

# Reset and rebuild
npm run reset
```

JavaScript source files are in `js/source/` and bundled output goes to `js/build/`. Webpack configuration is in `js/build.webpack.config.js`.

### Linting

The project uses super-linter in GitHub Actions. Configuration is in `.github/workflows/linter.yml`. HTML linting config is in `.github/linters/.htmlhintrc`.

### Database Patches

Database patches are stored in numbered directories under `db/` (e.g., `db/00001/`, `db/00002/`). Each patch is a Perl module that runs schema changes. The fixture database is loaded and patches are applied during test setup via `t/test_fixture.pl --dumpupdatedfixture`.

## Architecture

### Backend Structure

#### lib/SGN/ - Catalyst Application Layer

- **lib/SGN.pm**: Main Catalyst application entry point with roles and configuration
- **lib/SGN/Controller/**: Catalyst controllers handling HTTP requests
  - Main controllers for page rendering (e.g., `Stock.pm`, `Trial.pm`, `BreedersToolbox.pm`)
  - **lib/SGN/Controller/AJAX/**: REST API endpoints returning JSON
    - `AJAX/Stock.pm`, `AJAX/Trial.pm`, `AJAX/Phenotypes.pm`, etc.
    - Handle asynchronous requests from JavaScript frontend
- **lib/SGN/View/**: Catalyst view components
  - `View/Mason.pm`: HTML::Mason template rendering
  - `View/Email.pm`: Email generation
  - `View/Download/`: File download views
- **lib/SGN/Model/**: Catalyst models (thin layer over CXGN modules)
- **lib/SGN/Authentication/**: Custom authentication store for user login
- **lib/SGN/Role/**: Catalyst roles providing shared functionality across the app
- **lib/SGN/Feature/**: GBrowse genome browser integration
- **lib/SGN/SiteFeatures/**: Site-specific feature configuration

#### lib/CXGN/ - Core Business Logic

All CXGN modules are Moose-based and contain the core application logic.

- **lib/CXGN/Stock/**: Germplasm and stock management
  - `Stock/Accession.pm`: Individual accession handling
  - `Stock/Plot.pm`: Field plot management
  - `Stock/Seedlot.pm`: Seed lot inventory
  - `Stock/ParseUpload.pm`: Bulk stock upload parsing
  - `Stock/Order.pm`: Stock ordering system
  - Handles all germplasm, accessions, plots, plants, seedlots, and tissue samples

- **lib/CXGN/Trial/**: Field trial and experiment management
  - `Trial/TrialCreate.pm`: Creating new trials
  - `Trial/TrialDesign.pm`: Experimental design generation (RCBD, Alpha, Augmented, etc.)
  - `Trial/TrialLayoutDownload.pm`: Export trial layouts
  - `Trial/FieldMap.pm`: Field map visualization
  - `Trial/Folder.pm`: Trial organization in folders
  - Manages field trials, nurseries, screenhouse experiments, crossing blocks

- **lib/CXGN/Phenotypes/**: Phenotypic data management
  - `Phenotypes/ParseUpload.pm`: Phenotype data upload and validation
  - `Phenotypes/PhenotypeMatrix.pm`: Generate phenotype matrices
  - `Phenotypes/StorePhenotypes.pm`: Store phenotype observations
  - `Phenotypes/HighDimensionalPhenotypes*.pm`: NIRS, metabolomics data
  - Handles trait observations, data collection, phenotype storage

- **lib/CXGN/Genotype/**: Genotypic data management
  - `Genotype/Protocol.pm`: Genotyping protocol/platform management
  - `Genotype/ParseUpload.pm`: VCF, dosage matrix, HapMap uploads
  - `Genotype/GRM.pm`: Genomic relationship matrix calculation
  - `Genotype/GWAS.pm`: Genome-wide association studies
  - `Genotype/Search.pm`: Genotype data queries
  - Manages SNP data, GBS, SSR markers, genotyping protocols

- **lib/CXGN/BreedersToolbox/**: Breeding workflow tools
  - `BreedersToolbox/Accessions.pm`: Accession management utilities
  - `BreedersToolbox/Projects.pm`: Breeding program/project management
  - `BreedersToolbox/Delete.pm`: Deletion workflows with validation
  - `BreedersToolbox/ProductProfile.pm`: Target product profiles
  - High-level breeding operations and workflows

- **lib/CXGN/Pedigree/**: Pedigree and crossing management
  - `Pedigree/AddCrosses.pm`: Record crosses between parents
  - `Pedigree/AddCrossingtrial.pm`: Crossing nursery management
  - `Pedigree/AddProgenies*.pm`: Progeny generation
  - `Pedigree/AddGrafts.pm`: Grafting relationships
  - `Pedigree/ParseUpload.pm`: Bulk pedigree uploads
  - Manages crosses, progenies, parent-offspring relationships

- **lib/CXGN/List/**: User list/set management
  - `List/Validate.pm`: Validate list contents against database
  - `List/Transform.pm`: Transform list types (accessions→plots→tissues)
  - `List/FuzzySearch.pm`: Fuzzy matching for list items
  - Users create lists of accessions, traits, trials, etc. for analysis

- **lib/CXGN/Dataset/**: Dataset creation for analysis
  - Flexible dataset definition using combinations of:
    - Lists of germplasm, trials, traits, years, locations
  - Once defined, retrieve associated phenotypes/genotypes
  - `Dataset/File.pm`: Write datasets to files
  - `Dataset/Cache.pm`: Cached dataset queries

- **lib/CXGN/Location/**: Geographic location management
  - Trial locations, GPS coordinates, location metadata

- **lib/CXGN/People/**: User and community features
  - `People/Roles.pm`: User role management (submitter, curator, admin)
  - `People/Forum.pm`: Discussion forums
  - `People/PageComment.pm`: Page comments
  - User accounts, permissions, community engagement

- **lib/CXGN/Image/**: Image upload and management
  - `Image/Search.pm`: Image search and retrieval
  - Handles plot images, plant images, drone imagery metadata

- **lib/CXGN/DroneImagery/**: Drone and high-throughput phenotyping
  - `DroneImagery/ImagesSearch.pm`: Query drone imagery
  - `DroneImagery/ImageTypes.pm`: Image type categorization
  - Integration with external image analysis services

- **lib/CXGN/BrAPI/**: Breeding API (BrAPI) implementation
  - `BrAPI/JSONResponse.pm`: Standard JSON response formatting
  - `BrAPI/Pagination.pm`: Result pagination
  - `BrAPI/FileResponse.pm`: File download responses
  - RESTful API following BrAPI standards for interoperability

- **lib/CXGN/Analysis/**: Analysis workflow management
  - `Analysis/AnalysisCreate.pm`: Create analysis records
  - Links to R scripts, manages analysis metadata

- **lib/CXGN/Trait/**: Trait ontology management
  - Trait definitions, ontology terms, composable variables

- **lib/CXGN/Page/**: Legacy page utilities (pre-Catalyst)
  - Form helpers, formatting, widgets
  - Mostly legacy code being phased out

- **lib/CXGN/Search/**: Legacy search framework
  - Older search interfaces, being replaced by modern controllers

- **lib/CXGN/Blast/**: BLAST sequence search integration
- **lib/CXGN/Bulk/**: Bulk download tools
- **lib/CXGN/Cview/**: Chromosome viewer (legacy)
- **lib/CXGN/DB/**: Database connection and query utilities
- **lib/CXGN/File/**: File handling utilities
- **lib/CXGN/Graphics/**: Plot and chart generation (GD-based)
- **lib/CXGN/Marker/**: Molecular marker management
- **lib/CXGN/ODK/**: ODKCollect (mobile data collection) integration
- **lib/CXGN/Fieldbook/**: Android Fieldbook app integration
- **lib/CXGN/Phylo/**: Phylogenetic tree tools
- **lib/CXGN/Propagation/**: Plant propagation tracking
- **lib/CXGN/String/**: String manipulation utilities
- **lib/CXGN/TrackingActivity/**: Activity tracking and logging
- **lib/CXGN/Transcript/**: Transcript/gene expression data
- **lib/CXGN/Transformation/**: Genetic transformation tracking

#### lib/Bio/ - Bioinformatics Modules

- **lib/Bio/BLAST2/**: BLAST database and search functionality
- **lib/Bio/GeneticRelationships/**: Genetic relationship calculations
- **lib/Bio/SecreTary/**: Secreted protein prediction

#### lib/solGS/ - Genomic Selection

- **lib/solGS/**: R-based genomic selection interface
  - `solGS/queryJobs.pm`: Query analysis job status
  - `solGS/JobSubmission.pm`: Submit R jobs for GS analysis
  - Interfaces with R scripts for genomic prediction models

#### lib/PDF/ - PDF Generation

- PDF document generation utilities

### Frontend Structure

- **mason/**: HTML::Mason templates (`.mas` files) organized by feature
  - `mason/breeders_toolbox/`: Breeding tools UI
  - `mason/stock/`: Stock pages
  - `mason/trial/`: Trial pages
  - `mason/chado/`: Chado database object pages
- **js/source/**: Modern JavaScript modules (ES6+)
  - `js/source/legacy/`: Legacy JavaScript moved from root
- **static/**: Static assets (CSS, images, documents)
- **cgi-bin/**: Legacy CGI scripts (being phased out)

### Database

Uses PostgreSQL with Chado schema (biological database schema) plus custom extensions. Key Chado modules:
- `stock`: Germplasm, accessions, plots
- `project`: Trials, experiments
- `phenotype`: Phenotypic observations
- `genotype`: Genotypic data
- `cvterm`: Controlled vocabulary terms

### R Analytics

R scripts in `R/` directory provide statistical analysis:
- `R/mixed_models.R`: Mixed model analysis
- `R/heritability/`: Heritability calculations
- `R/GCPC.R`: Genomic prediction
- `R/dataset/`: Dataset-specific analysis

Backend Perl code calls R scripts via system commands, typically through `CXGN::Analysis::*` modules.

## Key Patterns

### Adding New Features

1. **Backend**: Create/modify Moose module in `lib/CXGN/` with business logic
2. **Controller**: Add Catalyst controller in `lib/SGN/Controller/` or AJAX endpoint in `lib/SGN/Controller/AJAX/`
3. **Frontend**: Add Mason template in `mason/` and JavaScript in `js/source/`
4. **Tests**: Add test in appropriate `t/` subdirectory
5. **Database**: If schema changes needed, create patch in new `db/` directory
6. **Documentation**: Update user manual in `docs/` if user-facing

### Fixture Data

When adding test data, prefer patches in `t/data/fixture/patches/` over modifying fixture directly. This makes changes reviewable and reproducible.

### JavaScript Organization

- New JavaScript goes in `js/source/` as ES6 modules
- Legacy code should be moved to `js/source/legacy/`
- Build process bundles everything via webpack
- Document with JSDoc comments

### Perl Documentation

Use POD (perldoc) format for Perl modules:
```perl
=head1 NAME

Module::Name - Brief description

=head1 SYNOPSIS

Usage example

=head1 DESCRIPTION

Detailed description

=head1 METHODS

=head2 method_name

Method description

=cut
```

## Configuration

Main config files:
- `sgn.conf`: Production/development configuration
- `sgn_test.conf`: Test-specific configuration
- `sgn_fixture_template.conf`: Template for fixture tests

Important config sections:
- Database connection: `dbhost`, `dbname`, `dbuser`
- Paths: `rootpath`, `basepath`
- BrAPI settings: `brapi_*` keys
- Feature flags: Various boolean toggles for features

## Test Categories

- **t/unit/**: Unit tests, no database required
- **t/unit_fixture/**: Tests requiring fixture database
  - `t/unit_fixture/CXGN/`: Tests for CXGN modules
  - `t/unit_fixture/SGN/`: Tests for SGN modules
  - `t/unit_fixture/Controller/`: Controller tests
  - `t/unit_fixture/AJAX/`: AJAX endpoint tests
- **t/unit_mech/**: Mechanize-based controller tests
- **t/selenium2/**: Selenium browser integration tests
- **t/live/**: Tests against live external services

## Important Notes

- This is a Docker-based deployment system; development typically happens in containers
- The system implements BrAPI (Breeding API) standards
- Multiple breeding databases share this codebase with different configurations
- Mason templates mix HTML with Perl code; use `<& component.mas &>` for includes
- The fixture database is essential for most tests and is loaded automatically by test_fixture.pl
