# BuildingSync Gem

## Version 0.2.0

This is released as a minor version since we are so early stage, even though it has many breaking changes.  Most of the 'high-level API' (translator) remains.

- Added many BuildingSync specific classes:
    - AllResourceTotal
    - AuditDate
    - Contact
    - Report
    - ResourceUse
    - Scenario
    - TimeSeries
    - Utility

- Major modifications to:
    - WorkflowMaker
    - Building
    - BuildingSection
    - Facility
    - HVACSystem
    - LightingSystem
    - LoadsSystem
    - Site
    - SpatialElement
    - Translator
    
- Added / modified modules / classes:
    - Generator
    - Helper
    - XmlGetSet: many useful functions to get / set XML data given a base_xml
    - LocationElement
    
- Removed Classes:
    - ModelMakerBase
    - ModelMaker
    - MeteredEnergy
    
- Added `constants.rb`
- Renamed `bldg_and_system_types.json1` -> `building_and_system_types.json`
- Removed redundant / unused XML files
- Updated files to comply with specific BSync versions (v2.1.0, v2.2.0)
- Significantly more testing

## Version 0.1.0

* Initial release
* Support Level 0 (walkthrough), Level 1, and simplified Level 2 energy audits specified by ASHRAE Standard 211-2018. 
* Support Office, Retail, and Hotel Building Types
