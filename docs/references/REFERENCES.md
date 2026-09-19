# References — register

The single bibliography of the ecosystem pipeline (GUIDE Stage C). Each row:
id, citation, where the owner's copy lives, what it is needed for.

- **Local copies are in the DATAPOOL, not in this repository** (owner layout;
  checksums in the manifests named in the last column).
- **A verification item (CONCEPT V-…) closes only when its number is read
  from the registered document**, with the page cited.
- Rows marked *(DOI)* have no local copy.
- `<ROOT>` = `READING_DATA_POOL`.
- Manifests: `GRACEFO\DOCUMENTS\SHA256SUMS_documents_2026-09-19.txt` (220
  documents), plus the data manifests of GUIDE Stage B.

## Mission documents

| id | citation | local copy | needed for |
|---|---|---|---|
| R-1 | Wu, S.-C., Kruizinga, G., Bertiger, W. (2006): *Algorithm Theoretical Basis Document for GRACE Level-1B Data Processing*, V1.2, GRACE 327-741, JPL D-27672 | `<ROOT>\GRACE\DOCUMENTS\Level-1\GRACE_Algorithm_Theoretical_Basis_Document_for_GRACE_L1B_Data_Processing.pdf` | V-1, V-2, ORC-1 (App. B, printed p. 39 = PDF p. 40) |
| R-2 | Wen, H. Y., Kruizinga, G., Paik, M., Landerer, F., Bertiger, W., Sakumura, C., Bandikova, T., McCullough, C. (2019): *GRACE-FO Level-1 Data Product User Handbook*, JPL D-56935 | `<ROOT>\GRACEFO\DOCUMENTS\Level-1\GRACE-FO_L1_Data_Product_User_Handbook_20190911.pdf` | V-1, V-2, V-3, V-13, masks (fill rules), G-04 |
| R-3 | McCullough, C., Harvey, N., Save, H., Bandikova, T. (2019): *Description of Calibrated GRACE-FO Accelerometer Data Products (ACT)*, JPL D-103863 | `<ROOT>\GRACEFO\DOCUMENTS\Level-1\GRACE-FO_ACT_Product_Description_20190520.pdf` | V-5 |
| R-4 | Case, K., Kruizinga, G., Wu, S.-C. (2010): *GRACE Level 1B Data Product User Handbook*, JPL D-22027 | `<ROOT>\GRACE\DOCUMENTS\Level-1\GRACE_L1B_Data_Product_User_Handbook.pdf` | V-8, G-02 |
| R-5 | Bettadpur, S. (2012): *GRACE Product Specification Document*, Rev 4.6, GRACE 327-720 (CSR-GR-03-02) — includes the **GRACE macro model** (§I.5.3.3–I.5.3.6) | `<ROOT>\GRACE\DOCUMENTS\GENERAL\GRACE_Product_Specification_Document.pdf` | V-9, N-07 |
| R-6 | GRACE-FO TN-01 SOE, TN-01a SCE, TN-01b KBR/GPS statistics (living documents); GRACE TN-01 SOE (2018) and TN-03 SOE format description | `<ROOT>\GRACEFO\DOCUMENTS\TECHNICAL_NOTES\<date>\`, `<ROOT>\GRACE\DOCUMENTS\TECHNICAL_NOTES\` | G-05, X-05, V-12 |
| R-7 | JPL: *GRACE-FO Level-1 Release Notes* (log, last entry 2022-05-10: ACX, LRI phase-jump processing from 2020-06-27); GRACE-FO SDS newsletters 001–028 | `<ROOT>\GRACEFO\DOCUMENTS\RELEASE_NOTES\`, `…\NEWSLETTER\` | V-16, event history |
| R-8 | AEI: *AEI LRI1B release notes* (v52); Misfeldt et al. 2023 (see P-11) | `<ROOT>\GRACEFO\L1B\AEI_v52\` | ORC-13, L-09 |
| R-9 | TU Graz ITSG operational products: `README.txt`, `README_referenceFrames.txt` | `<ROOT>\ITSG\` | V-4 |
| R-10 | Bettadpur, S. (2009): *GRACE TN-02, Recommendation for a-priori Bias & Scale Parameters for Level-1B ACC Data* (v2) — convention f_new = bias + scale × f_ACC1B | `<ROOT>\GRACE\DOCUMENTS\TECHNICAL_NOTES\TN-02_ACC_Calibration_v2.pdf` | ORC-10 (classic), N-08 priors |
| R-11 | Thomas, J. B. (1999): *An Analysis of Gravity-Field Estimation Based on Intersatellite Dual-1-Way Biased Ranging*, JPL Publication 98-15 — the CRN filter's origin (App. A.3.4, p. A-16 = PDF p. 102; scanned, no text layer) | `<ROOT>\GRACE\DOCUMENTS\ANCILLARY\An_Analysis_of_Gravity_Field_Estimation_based_on_Inter-satellite_Dual_One-Way_Biased_Ranging.pdf` | ORC-1 |
| R-12 | GRACE TN-04 (guide to GFZ RL03 / JPL RL02), GRACE JPL L1 release notes RL00/RL01; GRACE SDS newsletters 2004–2017 | `<ROOT>\GRACE\DOCUMENTS\TECHNICAL_NOTES\`, `…\RELEASE_NOTES\`, `…\NEWSLETTER\` | classic event history |
| R-13 | Wöske, F., Rievers, B., Huckfeldt, M. et al. (2024): *Tailored accelerometer calibration by POD for thermospheric density retrieval with GRACE and GRACE-FO*, Adv. Space Res. 74:4517–4542, doi:10.1016/j.asr.2024.09.021 — and the ZARM data set | `<ROOT>\ZARM\` (data); paper *(DOI)* | ORC-10 |

## Papers (DOI; a local copy only where open access and already fetched)

| id | citation | needed for |
|---|---|---|
| P-1 | Bandikova, T., McCullough, C., Kruizinga, G. L., Save, H., Christophe, B. (2019): GRACE accelerometer data transplant, Adv. Space Res. 64:623–644, doi:10.1016/j.asr.2019.05.021 | V-5, ORC-12 |
| P-2 | Behzadpour, S., Mayer-Gürr, T., Krauss, S. (2021): GRACE Follow-On accelerometer data recovery, JGR Solid Earth 126:e2020JB021297, doi:10.1029/2020JB021297 | V-4, V-10, N-11 |
| P-3 | Harvey, N., McCullough, C. M., Save, H. (2022): Modeling GRACE-FO accelerometer data for the version 04 release, Adv. Space Res., doi:10.1016/j.asr.2021.09.008 | V-5, ORC-12 |
| P-4 | Klinger, B., Mayer-Gürr, T. (2016): The role of accelerometer data calibration within GRACE gravity field recovery, Adv. Space Res. 58:1597–1609, doi:10.1016/j.asr.2016.08.007 | N-02, N-11 |
| P-5 | Kvas, A. et al. (2019): ITSG-Grace2018, JGR Solid Earth, doi:10.1029/2019JB017415 | context |
| P-6 | Peterseim, N., Flury, J., Schlicht, A. (2012): Magnetic torquer induced disturbing signals within GRACE accelerometer data, Adv. Space Res., doi:10.1016/j.asr.2012.02.013 | X-17, N-11 |
| P-7 | Pan, Xiao (2024): Sensors 24:4286, doi:10.3390/s24134286 | X-17 |
| P-8 | Yan, Y., Müller, V., Heinzel, G., Zhong, M. (2021): Revisiting the light time correction in gravimetric missions like GRACE and GRACE Follow-On, J. Geod. 95:48, doi:10.1007/s00190-021-01498-5 | L-01 |
| P-9 | Müller, V. et al. (2022): Comparing GRACE-FO KBR and LRI ranging data with focus on carrier frequency variations, Remote Sens. 14:4335, doi:10.3390/rs14174335 | L-03, L-07, L-08 |
| P-10 | Müller, V., Yan, Y. et al. (2025): Re-analysing the data processing of the K-band ranging system on GRACE Follow-On, J. Geod. 99, doi:10.1007/s00190-025-01988-w | L-08 |
| P-11 | Misfeldt, M. et al. (2023): Scale factor determination for the GRACE Follow-On laser ranging interferometer including thermal coupling, Remote Sens. 15:570, doi:10.3390/rs15030570 — **local copy** `<ROOT>\GRACEFO\L1B\AEI_v52\Misfeldt2023_ScaleFactor_LRI_ThermalCorrection.pdf` | L-09 |
| P-12 | Wegener, H. et al. (2020): Tilt-to-length coupling in the GRACE Follow-On LRI, J. Spacecraft Rockets 57:1362, doi:10.2514/1.A34790 | L-07 |
| P-13 | Abich, K. et al. (2019): In-orbit performance of the GRACE Follow-On laser ranging interferometer, Phys. Rev. Lett. 123:031101, doi:10.1103/PhysRevLett.123.031101 | L-02 |
| P-14 | Harvey, N., Sakumura, C. (2019): Results from a GRACE/GRACE-FO attitude reconstruction Kalman filter | N-12 |
| P-15 | Ren et al. (2022): Remote Sens. 14:126, doi:10.3390/rs14010126 | N-12 |
| P-16 | Hu et al. (2022): Remote Sens. 14:3395; Li et al. (2025): Remote Sens. 17:353, doi:10.3390/rs17030353 | L-07 |
| P-17 | Siemes, C. et al. (2023): New thermosphere neutral mass density and crosswind datasets from CHAMP, GRACE, and GRACE-FO, J. Space Weather Space Clim. 13, doi:10.1051/swsc/2023014 | ORC-10 (second source), V-10 |
| P-18 | Vielberg, K. et al. (2020): Extended forward and inverse modeling of radiation pressure accelerations for LEO satellites, J. Geod. 94, doi:10.1007/s00190-020-01368-6 | N-07 |
| P-19 | Tapley, B. D. et al. (2015): The GRACE mission: status and performance assessment (thermal-control history) | V-10 |
| P-20 | Jacobs, F., Hładczuk, N., van den IJssel, J., Siemes, C., Visser, P. (2026): Joint optimization of a GRACE radiation pressure model, the accelerometer scale factors, and an empirical magnetic-field-induced accelerometer bias, Adv. Space Res. 77(12):12096–12121, doi:10.1016/j.asr.2026.04.043 | N-07, N-11 |

Full-text copies of papers are not fetched automatically. Where a paper is
open access and a work package needs its equations, the Session adds the copy
to the DATAPOOL and fills in the path here.
