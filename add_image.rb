require 'xcodeproj'
project_path = 'MonoSync.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('image', true)
file_ref = group.new_reference('image/tape_N3.png')
file_ref.name = 'tape_N3.png'
file_ref.path = 'tape_N3.png'

target.resources_build_phase.add_file_reference(file_ref)
project.save
