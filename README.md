# Amortizing Swap Pricing under a Multi-Curve Interest Rate Model with CVA

## Project Overview

This project focuses on pricing an amortizing Interest Rate Swap (IRS) within a multi-curve framework. A discounting curve (OIS ESTR) and a pseudo-discounting curve (Euribor3M) are constructed using the “Crab” approach. Additionally, we compute the Credit Value Adjustment (CVA) to account for counterparty credit risk. To achieve this, two methodologies are implemented: an analytic approach, pricing physical delivery swaptions via the Bachelier model, and a numerical approach. The latter employs a parsimonious Multi-Curve Hull-White (MHW) model, a framework that extends the original HW model by introducing just one additional spread parameter γ, which allocates the volatility between the two curves. The model is first calibrated by pricing swaptions via a generalized Jamshidian approach. Once calibrated, it is implemented on a recombining trinomial tree to numerically price the amortizing swap. 

## Repository Structure


- **biblio/**
  - References, papers, and bibliography used throughout the project

- **data/**
  - Market data and input datasets used for calibration and pricing

- **utilities/**
  - Collection of MATLAB functions and helper scripts implemented for the project

- **runProject_1A.m**
  - Main script used to execute the full project workflow

- **Project1_CVA_Multicurve.pdf**
  - Main project document containing instructions and methodology

## Requirements

- MATLAB
- Financial Toolbox (MATLAB)

## Execution

Run the main script:

runProject_1A
