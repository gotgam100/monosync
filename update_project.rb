require 'xcodeproj'

project_path = '/Users/baekmac/맥북_Home/01_개인작업/05_CODE/MonoSync/MonoSync.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# 1. Remove ANY references matching our file names from the build phase
names_to_remove = [
  'MyStationView.swift',
  'YourStationView.swift',
  'StationStore.swift',
  'StationComment.swift',
  'FriendsView.swift',
  'RadioView.swift'
]

target.source_build_phase.files.to_a.each do |build_file|
  ref = build_file.file_ref
  if ref && names_to_remove.include?(ref.name || ref.path)
    target.source_build_phase.remove_build_file(build_file)
    ref.remove_from_project
    puts "Removed duplicate/old #{ref.path}"
  end
end

# 2. Add them back with explicit absolute paths so Xcodeproj resolves them perfectly
base_dir = '/Users/baekmac/맥북_Home/01_개인작업/05_CODE/MonoSync/MonoSync'
files_to_add = [
  "#{base_dir}/Views/Station/MyStationView.swift",
  "#{base_dir}/Views/Station/YourStationView.swift",
  "#{base_dir}/Services/StationStore.swift",
  "#{base_dir}/Domain/StationComment.swift"
]

files_to_add.each do |abs_path|
  file_ref = project.main_group.new_reference(abs_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{abs_path}"
end

project.save
puts "Project saved successfully"
