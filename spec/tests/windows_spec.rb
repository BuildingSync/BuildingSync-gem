# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************


def get_facility_with_fenestration_systems(fenestration_systems)
  doc_string = REXML::Document.new("""
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <auc:BuildingSync
      xmlns:auc=\"http://buildingsync.net/schemas/bedes-auc/2019\"
      xsi:schemaLocation=\"http://buildingsync.net/schemas/bedes-auc/2019
      https://raw.githubusercontent.com/BuildingSync/schema/v2.4.0/BuildingSync.xsd\"
      xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
      version=\"2.4.0\">
      <auc:Facilities>
        <auc:Facility ID=\"Facility1\">
          <auc:Sites>
            <auc:Site ID=\"Site1\">
              <auc:Buildings>
                <auc:Building ID=\"Building1\">
                  <OccupancyClassification>Office</OccupancyClassification>
                  <auc:YearOfConstruction>2000</auc:YearOfConstruction>
                </auc:Building>
              </auc:Buildings>
            </auc:Site>
          </auc:Sites>
          <auc:Reports>
            <auc:Report></auc:Report>
          </auc:Reports>
          <auc:Systems>
            #{fenestration_systems}
          </auc:Systems>
        </auc:Facility>
      </auc:Facilities>
    </auc:BuildingSync>
  """, {ignore_whitespace_nodes: :all})

  return BuildingSync::Facility.new(
    doc_string.elements["/auc:BuildingSync/auc:Facilities/auc:Facility"],
    @ns = 'auc',
    ""
  )
end

RSpec.describe 'BuildingSync Windows' do
  describe 'get_window_data should' do
      good_window = """
        <auc:FenestrationSystem ID='1' xmlns:auc=\"http://buildingsync.net/schemas/bedes-auc/2019\">
          <auc:FenestrationType>
            <auc:Window/>
          </auc:FenestrationType>
          <auc:FenestrationFrameMaterial>Aluminum no thermal break</auc:FenestrationFrameMaterial>
          <auc:FenestrationOperation>false</auc:FenestrationOperation>
          <auc:TightnessFitCondition>Average</auc:TightnessFitCondition>
          <auc:GlassType>Clear uncoated</auc:GlassType>
          <auc:FenestrationGlassLayers>Single pane</auc:FenestrationGlassLayers>
          <auc:SolarHeatGainCoefficient>0.391000</auc:SolarHeatGainCoefficient>
          <auc:VisibleTransmittance>0.391000</auc:VisibleTransmittance>
          <auc:FenestrationUFactor>3.241000</auc:FenestrationUFactor>
        </auc:FenestrationSystem>
      """
      invalid_window = """
        <auc:FenestrationSystem ID='2' xmlns:auc=\"http://buildingsync.net/schemas/bedes-auc/2019\">
          <auc:FenestrationType>
            <auc:Window/>
          </auc:FenestrationType>
          <auc:FenestrationFrameMaterial>Fiberglass</auc:FenestrationFrameMaterial>
          <auc:FenestrationOperation>false</auc:FenestrationOperation>
          <auc:TightnessFitCondition>Average</auc:TightnessFitCondition>
          <auc:GlassType>Clear uncoated</auc:GlassType>
          <auc:FenestrationGlassLayers>Single pane</auc:FenestrationGlassLayers>
          <auc:SolarHeatGainCoefficient>0.391000</auc:SolarHeatGainCoefficient>
          <auc:VisibleTransmittance>0.391000</auc:VisibleTransmittance>
          <auc:FenestrationUFactor>3.241000</auc:FenestrationUFactor>
        </auc:FenestrationSystem>
      """
      door = """
        <auc:FenestrationSystem ID=\"FenestrationSystemType-45021100\">
          <auc:FenestrationType>
            <auc:Door>
              <auc:ExteriorDoorType>Uninsulated metal</auc:ExteriorDoorType>
            </auc:Door>
          </auc:FenestrationType>
        </auc:FenestrationSystem>
      """

    it "work in happy case" do
      # Set Up
      facility = get_facility_with_fenestration_systems("""
        <auc:FenestrationSystems>
          #{good_window}
        </auc:FenestrationSystems>
      """)
      # Action
      window_pane_type, fenestration_u_factor, solar_heat_gain_coefficient, visible_transmittance = facility.get_window_data
      # Assertion
      expect(window_pane_type).to eq "Single - No LowE - Clear - Aluminum"
      expect(fenestration_u_factor).to eq "3.241000"
      expect(solar_heat_gain_coefficient).to eq "0.391000"
      expect(visible_transmittance).to eq "0.391000"
    end

    it "ignore doors and skylights" do
      # Set Up
      facility = get_facility_with_fenestration_systems("""
        <auc:FenestrationSystems>
          #{door}
          #{good_window}
        </auc:FenestrationSystems>
      """)
      # Action
      window_pane_type, fenestration_u_factor, solar_heat_gain_coefficient, visible_transmittance = facility.get_window_data
      # Assertion
      expect(window_pane_type).to eq "Single - No LowE - Clear - Aluminum"
      expect(fenestration_u_factor).to eq "3.241000"
      expect(solar_heat_gain_coefficient).to eq "0.391000"
      expect(visible_transmittance).to eq "0.391000"    end

    it "work if first window is invalid but second isnt" do
      # Set Up
      facility = get_facility_with_fenestration_systems("""
        <auc:FenestrationSystems>
          #{invalid_window}
          #{good_window}
        </auc:FenestrationSystems>
      """)
      # Action
      window_pane_type, fenestration_u_factor, solar_heat_gain_coefficient, visible_transmittance = facility.get_window_data
      # Assertion
      expect(window_pane_type).to eq "Single - No LowE - Clear - Aluminum"
      expect(fenestration_u_factor).to eq "3.241000"
      expect(solar_heat_gain_coefficient).to eq "0.391000"
      expect(visible_transmittance).to eq "0.391000"    end

    it "return nil if there are no windows" do
      # Set Up
      facility = get_facility_with_fenestration_systems("")
      # Action
      window_pane_type, fenestration_u_factor, solar_heat_gain_coefficient, visible_transmittance = facility.get_window_data
      # Assertion
      expect(window_pane_type).to eq nil
    end

    # warn not error
    it "return nil if all windows are invalid" do
      # Set Up
      facility = get_facility_with_fenestration_systems("""
        <auc:FenestrationSystems>
          #{invalid_window}
        </auc:FenestrationSystems>
      """)
      # Action
      window_pane_type, fenestration_u_factor, solar_heat_gain_coefficient, visible_transmittance = facility.get_window_data
      # Assertion
      expect(window_pane_type).to eq nil
    end
  end
end
