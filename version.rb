module Version
  def self.work_on(dir)
    dir = File.readlink(dir) if File.symlink?(dir)
    raise "unknown directory #{dir}" unless File.directory?(dir) # only directories are of any interest

    Dir.chdir(dir) do
      if File.directory?('CVS')
        version_system = :cvs
      elsif File.directory?('.svn')
        version_system = :svn
      elsif File.directory?('.hg')
        version_system = :hg
      elsif File.directory?('.bzr')
        version_system = :bzr
      elsif File.directory?('.git/svn')
        version_system = :git_svn
      elsif File.directory?('.git')
        version_system = :git
      elsif File.exist?('.gclient')
        version_system = :gclient
      else
        raise "unknown revision control system"
      end

      yield(Dir.pwd, version_system) # we want the full directory name
    end
  end

  def self.update(dir)
    work_on(dir) do |dir, version_system|
      case version_system
      when :cvs
        ENV['CVS_RSH'] = 'ssh' if /ssh/.match(dir) # if we have to run CVS via SSH
        IO.popen('cvs -z3 update -Pd 2>&1') do |f|
          # we do not care about the lines telling us about the files ignored by CVS and thoses with the name of the processed directory
          while output = f.gets
            puts output unless /^cvs update:/.match(output) or /^\? /.match(output)
          end
        end
        ENV['CVS_RSH'] = nil
      when :svn then system 'svn up'
      when :hg  then system 'hg pull -u'
      when :bzr then system 'bzr up'
      when :git then
        system 'git fetch -p'
        system 'git pull'
        system 'git submodule update --init' if File.exist?('.gitmodules')
      when :git_svn then
        system 'git svn fetch'
        system 'git svn rebase'
      when :gclient then
        system '$HOME/src/depot_tools/gclient sync'
      else
        raise "unknown revision control system"
      end
    end
    $?.to_i
  end

  def self.log(dir)
    work_on(dir) do |dir, version_system|
      if File.exist?('ChangeLog')
        system 'less ChangeLog'
      else
        case version_system
        when :svn then system 'svn log 2>&1 | less'
        when :hg then system 'hg log'
        when :bzr then system 'bzr log'
        when :git, :git_svn then system 'git log'
        else
          raise "can't get the log"
        end
      end
    end
    $?.to_i
  end

  def self.repack(dir)
    work_on(dir) do |dir, version_system|
      case version_system
      when :git, :git_svn then system 'git repack -a -d'
      else
        puts "can't repack"
      end
    end
    $?.to_i
  end
end
