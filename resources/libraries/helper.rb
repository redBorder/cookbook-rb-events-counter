module RbEventscounter
  module Helper
    def get_license_info(licenses_dir)
      begin
        licenses_dg = data_bag_item('rBglobal', 'licenses')
      rescue
        licenses_dg = { 'licenses' => {} }
      end

      current_licenses = licenses_dg['licenses'] || {}

      existing_licenses = if Dir.exist?(licenses_dir)
                            Dir.glob(File.join(licenses_dir, '*')).map { |f| File.basename(f) }
                          else
                            []
                          end

      licenses_to_remove = existing_licenses - current_licenses.keys

      {
        current_licenses: current_licenses,
        licenses_to_remove: licenses_to_remove
      }
    end
  end
end
