#!/bin/bash
##
# StarShip - (C) 2015 Jason Boudreault / Shaped.ca
# Description: starship.sh - main file, version 0.01a
# Usage: starship command [options]
##


starship () {
  STARSHIP_VERSION="0.01a"

  DEFAULT_OUTPUT="/opt/cloud-config"

  temp_files=""
  untarfiles=""
  _printedUsage=0
  _printedCommandHeader=0

  # prints version
  _printVersion() {
    echo "Shaped StarShip v$STARSHIP_VERSION"
  }

  # prints usage
  _printUsage() {
    if [ $_printedUsage == 0 ]; then _printedUsage=1;
      _printVersion
      echo "Usage: $0 command [options]"
    fi
  }

  # prints help
  _printHelp() {
    _printUsage $*
    echo
    echo "Available Commands: (parameters in square brackets are optional, while in parenthesis are required)"
    echo
    echo "process  (template) [output] [env]    Generates a .starship file from a template directory."
    echo "combine  (template) [output]          Combines files in your template directroy into a yaml file."
    echo "package  (template) [output]          Packages a template for distribution (does not process)."
    echo "explode  (template) [output]          Unpackages a packaged template."
    echo "validate (template)                   Combines if needed, processes and validates a template with coreos-cloudinit."
    echo "help     [command]                    Print full help, or help for specific command."
    echo
  }

  #prints usage and exits
  printUsage() {
    _printHelp $*
    exit
  }

  # prints all help
  printFullHelp() {
    _printHelp
    _getHelp process
    _getHelp combine
    _getHelp package
    _getHelp explode
    _getHelp validate
  }

  _getHelp () {
    if [ $_printedCommandHeader == 0 ]; then _printedCommandHeader=1;
      echo "Command Options:"
      echo
    fi
    case $1 in
      process)
        echo "process (template) [output] [env]     Processes a template for use with coreos-cloudinit and replaces variables"
        echo "                                      defined in your cloud-config template with ones in your system environment,"
        echo "                                      or the one provided with the optional [env]. You can pass any type of template"
        echo "                                      and starship will autodetect and work with it and yo"
        echo
        echo "  (template)                          The location of your template, can be URL or local file/directory."
        echo "  [output]                            The output file to use. Must be a writable file path. You also can set"
        echo "  [environment]                       An environment/script file to use - otherwise will use current environment."
        echo
      ;;
      combine)
        echo "combine (template) (output)           Combine files in a template directory into a single yaml file."
        echo "  (template)                          The location of your template, can be URL or local file/directory."
        echo "  (output)                            The output file for the yaml cloud-config template."
        echo
      ;;
      package)
        echo "package (template) (output)           Create a starship package for distribution."
        echo "  (template)                          The location of your template directory."
        echo "  (output)                            The output file for the binary starship file."
        echo
      ;;
      explode)
        echo "explode (template) (output)           Unpacks a starship package."
        echo "  (template)                          The location of the packed template."
        echo "  (output)                            The output directory (will be created if does not exist)."
        echo
      ;;
      validate)
        echo "validate (template)                   Process and validate a template with coreos-cloudinit - does not save template."
        echo "  (template)                          The location of your template, can be URL or local file/directory."
        echo
      ;;
      *)
        echo "Help unavailable for $1"
      ;;
    esac
  }

  # prints help
  getHelp () {
    _printHelp
    _getHelp $*
  }

  # adds a temp file to our stack for cleanup
  function addTF() {
    temp_files="$temp_files $1"
  }

  # removes tempfiles
  function cleanUp() {
    for x in $temp_files; do
      if [ ! -z $x ] && [ $x != "/" ] && [ $x != "/usr" ] && [ $x != "/root" ] && \
         [ $x != "/var" ] && [ $x != "/lib" ] && [ $x != "/tmp" ] && [ $x != "/home" ]; then
        if [ -d $x ]; then
          echo "Removing temp directory: $x"
          rm -rf $x
        fi
        if [ -f $x ]; then
         echo "Cleaning up temp file: $x"
         rm -rf $x
        fi
      fi
    done
  }

  # determines if file has the cloud-config header
  _hasCloudConfigHeader() {
    regex="#cloud-config"
    read -r line < $1
    if [[ "$line" =~ $regex ]]; then
     return 0;
    else
     return 1;
    fi
  }

  # validates a (single, combined) template file
  validateTemplate() {
    if _hasCloudConfigHeader $1; then
      if coreos-cloudinit -from-file=$1 -validate=true; then
        echo "Validation succeeded!"
       return 0;
      fi
    fi

    echo "Validation failed, please check your template!"
   exit 1;
  }

  # pulls the template from a url
  getTemplateFromURL() {
     tmp="/tmp/$(uuidgen)"

     if (curl -s $STARSHIP_TEMPLATE > $tmp); then
       addTF $tmp
       echo $tmp
     fi
  }

  # determines the template type
  getTemplateType() {
    if [[ $1 =~ https?:// ]]; then
      echo url
     return 0;
    else
      if file $1 | grep 'ASCII' > /dev/null; then
        echo file
       return 0;
      elif file $1 | grep 'gzip compressed' > /dev/null; then
        echo gzip
       return 0;
      elif file $1 | grep 'tar' > /dev/null; then
        echo tar
       return 0;
      elif file $1 | grep 'No such file' > /dev/null; then
        echo unknown
       return 1;
      elif file $1 | grep 'directory' > /dev/null; then
        echo dir
       return 0;
      fi
    fi
    echo unknown
    return 1;
  }

  compileDirectory() {
    tmp="/tmp/$(uuidgen)"
    files="$1/*"
    for f in $files; do
      echo ".. adding $f to $tmp"
      if _hasCloudConfigHeader $f; then x=1; else x=0; fi
      while IFS='' read -r l; do
        printf "%s\n" "$l" >> $tmp
      done < $f
    done
    addTF $tmp
    eval $2=$tmp
  }

  _handleUnTar() {
    tmpdir="/tmp/$(uuidgen)"
    mkdir -p $tmpdir
    addTF $tmpdir
    eval $3=$(tar xvf $1 -C $tmpdir/ > /dev/null)
    eval $2=$tmpdir
  }

  handleUnGzip() {
    if [ -z $3 ]; then
      tmp="/tmp/$(uuidgen)"
    else
      tmp=$3
    fi
    mkdir -p $tmp

    gunzip < $1 > $tmp/GZOUT

    if [ $(getTemplateType $tmp/GZOUT) == "tar" ]; then
      new="/tmp/$(uuidgen)"
      mv $tmp/GZOUT $new
      rmdir $tmp
      tmp=$new
      addTF $tmp
    else
      mv $tmp/GZOUT $tmp/cloud-config.yml
      addTF $tmp
      tmp=$tmp/cloud-config.yml
    fi

    eval $2=$tmp
  }

  handleUnTar() {
    _handleUnTar $STARSHIP_TEMPLATE dir files
    x=0
    for file in $files; do
      if [ $x = 0 ]; then
        path=$file
        echo $file
      fi
      let x=x+1
    done
    eval $2=$dir
  }

  unpackageTemplate() {
      echo "Accessing $STARSHIP_TEMPLATE to determine it's type"
      if [ $(getTemplateType $STARSHIP_TEMPLATE) = 'url' ]; then
          echo "The Template is a URL, fetching.."
          tmpl=$(getTemplateFromURL $STARSHIP_TEMPLATE)
          if [ ! -z $tmpl ]; then
            echo "Template fetched to $tmpl"
            STARSHIP_TEMPLATE=$tmpl
          else
            echo "Fetching template failed!"
            exit 1;
          fi
      fi

      while [ $(getTemplateType $STARSHIP_TEMPLATE) != "dir" ] &&
            [ $(getTemplateType $STARSHIP_TEMPLATE) != "file" ]; do
        case "$(getTemplateType $STARSHIP_TEMPLATE)" in
          gzip)
            echo ".. is gzipped package.."
            handleUnGzip $STARSHIP_TEMPLATE STARSHIP_TEMPLATE
            echo ".. unzipped to $STARSHIP_TEMPLATE"
          ;;
          tar)
            echo ".. is a tar package.."
            handleUnTar $STARSHIP_TEMPLATE STARSHIP_TEMPLATE
            echo ".. untarred to $STARSHIP_TEMPLATE/"
          ;;
          *)
            echo "There was an error, the template specified ($STARSHIP_TEMPLATE) isn't a URL, file, or directory!"
            echo
            printUsage
          ;;
        esac
      done
  }

  createPackage() {
    _CWD=$(pwd)

    case "$(getTemplateType $STARSHIP_TEMPLATE)" in
      file)
         echo "Creating $STARSHIP_OUTPUT package from $STARSHIP_TEMPLATE.."
         echo "Adding single file:"
         cd $(dirname $STARSHIP_TEMPLATE)
         #tar cvzf $_CWD/$STARSHIP_OUTPUT $(basename $STARSHIP_TEMPLATE) 2> /dev/null; cd $_CWD
         cp $(basename $STARSHIP_TEMPLATE) $(basename $STARSHIP_TEMPLATE).tmp
         gzip -S .starship $(basename $STARSHIP_TEMPLATE) 2> /dev/null;
         cp $(basename $STARSHIP_TEMPLATE).tmp $(basename $STARSHIP_TEMPLATE)
         mv $(basename $STARSHIP_TEMPLATE).starship $_CWD/$STARSHIP_OUTPUT
         cd $_CWD
      ;;
      dir)
         echo "Creating $STARSHIP_OUTPUT package from $STARSHIP_TEMPLATE/*.."
         echo "Adding files: "
         cd $(dirname $STARSHIP_TEMPLATE/*)
         tar cvzf $_CWD/$STARSHIP_OUTPUT * 2> /dev/null; cd $_CWD
      ;;
      *)
        echo "The createPackage function did not get passed a proper template or template directory and cannot continue!";
        exit 1;
      ;;
    esac

    echo "Done adding files!"

    echo Created $STARSHIP_OUTPUT \($(stat --printf="%s" $STARSHIP_OUTPUT) bytes\)
  }

  templateToFile() {
      echo "Accessing $STARSHIP_TEMPLATE to determine it's type"
      if [ $(getTemplateType $STARSHIP_TEMPLATE) = 'url' ]; then
          echo "The Template is a URL, fetching.."
          tmpl=$(getTemplateFromURL $STARSHIP_TEMPLATE)
          if [ ! -z $tmpl ]; then
            echo "Template fetched to $tmpl"
            STARSHIP_TEMPLATE=$tmpl
          else
            echo "Fetching template failed!"
            exit 1;
          fi
      fi

      while [ $(getTemplateType $STARSHIP_TEMPLATE) != "file" ]; do
        case "$(getTemplateType $STARSHIP_TEMPLATE)" in
          gzip)
            echo ".. is gzipped package.."
            handleUnGzip $STARSHIP_TEMPLATE STARSHIP_TEMPLATE
            echo ".. unzipped to $STARSHIP_TEMPLATE"
          ;;
          tar)
            echo ".. is a tar package.."
            handleUnTar $STARSHIP_TEMPLATE STARSHIP_TEMPLATE
            echo ".. untarred to $STARSHIP_TEMPLATE/"
          ;;
          dir)
            echo '.. is a directory..'
            compileDirectory $STARSHIP_TEMPLATE STARSHIP_TEMPLATE
            echo ".. combined to $STARSHIP_TEMPLATE"
          ;;
          *)
            echo "There was an error, the template specified ($STARSHIP_TEMPLATE) isn't a URL, file, or directory!"
            echo "It's of type: "
            echo $(getTemplateType $STARSHIP_TEMPLATE)
            echo
            printUsage
          ;;
        esac
      done
  }

  # process the template with and replaces variables with the environment.
  processTemplate() {
    replace_regex='\$\{([a-zA-Z_][a-zA-Z_0-9]*)\}'

    x=1
    tmp="/tmp/$(uuidgen)"
    while IFS='' read -r line; do
        while [[ "$line" =~ $replace_regex ]]; do
            param="${BASH_REMATCH[1]}"
             printf "Line \t%03d:" $x
            if [ -z ${!param} ]; then
              echo " found variable \${$param}: Not replacing (environment variable not set)"
              break
            else
              echo " found variable \${$param}: Replaced with: ${!param}"
              line=${line//${BASH_REMATCH[0]}/${!param}}
            fi
        done
      printf "%s\n" "$line" >> $tmp
      let x=x+1
    done < $STARSHIP_TEMPLATE

    touch $STARSHIP_OUTPUT
    if [ $? -ne 0 ]; then
        echo Exiting, unable to write to $STARSHIP_OUTPUT
        echo Your processed template is at $tmp
        exit 1
    fi

    echo "Post-validating processed result.."
    if validateTemplate $tmp; then
      mv $tmp $STARSHIP_OUTPUT
      echo "Your template has been processed! It is available at $STARSHIP_OUTPUT"
    else
      echo "Failed post-validating the processed result! The validation output above should help you fix the errors."
      echo "Check that the output generated at $tmp is valid YAML and that your variable replacements didn't break the syntax."
    fi

  }

  # set the default arguments
  doDefaults() {
      if [ -z $2 ] && [ -z $STARSHIP_TEMPLATE ]; then printUsage; fi
      if [ -z $STARSHIP_TEMPLATE ]; then STARSHIP_TEMPLATE=$2; fi
      if [ -z $STARSHIP_OUTPUT ]; then
        if [ -z $3 ]; then
          STARSHIP_OUTPUT=$DEFAULT_OUTPUT
        else
          STARSHIP_OUTPUT=$3
        fi
      fi
  }

  # process template function
  doProcess() {
      doDefaults $*

      echo About to begin processing template $STARSHIP_TEMPLATE..

      templateToFile

      echo "Pre-validating template.."
      if ! validateTemplate $STARSHIP_TEMPLATE; then
        echo "Pre-validation failed! We will attempt validation again after processing.."
        echo "However, you should try to correct any errors you see above.."
        echo -n "... press ^C and cancel ..."
        sleep 5
        echo -n $'\r'
      fi

      echo "Processing template $STARSHIP_TEMPLATE into $STARSHIP_OUTPUT.."
      processTemplate
  }

  # combine a template directory
  doCombine() {
      doDefaults $*

      echo Combining template $STARSHIP_TEMPLATE into $STARSHIP_OUTPUT

      templateToFile
  }

  # create a starship package
  doPackage() {
      FILEBASE=$(echo $2 | cut -d. -f1)
      DEFAULT_OUTPUT="$FILEBASE.starship"
      doDefaults $*

      echo Packaging template $STARSHIP_TEMPLATE into $STARSHIP_OUTPUT

      unpackageTemplate # ensure we are working with raw/local files
      createPackage     # and pack em up
  }

  # explode a starship package
  doExplode() {
     FILEBASE=$(echo $2 | cut -d. -f1)
     DEFAULT_OUTPUT="./$FILEBASE/"
     doDefaults $*

     unpackageTemplate

     mkdir -p $STARSHIP_OUTPUT

     if [ -d $STARSHIP_TEMPLATE ]; then
       mv $STARSHIP_TEMPLATE/* $STARSHIP_OUTPUT
     else
       mv $STARSHIP_TEMPLATE $STARSHIP_OUTPUT
     fi

     echo Exploded to $STARSHIP_OUTPUT
  }

  doValidate() {
      doDefaults $*

      templateToFile
      if ! validateTemplate $STARSHIP_TEMPLATE; then
        echo "Validation failed!";
      else
        echo "Validation passed!";
      fi
  }

  # Main Entrypoint
  echo Running: $0 $*
  echo
  case "$1" in
    process)
        doProcess $*
      ;;
    combine)
      if [ -z $2 ]; then printUsage; fi
        doCombine $*
      ;;
    package)
      if [ -z $2 ]; then printUsage; fi
        doPackage $*
      ;;
    explode)
      if [ -z $2 ]; then printUsage; fi
        doExplode $*
      ;;
    validate)
      if [ -z $2 ]; then printUsage; fi
        doValidate $*
      ;;
    help)
      if [ -z $2 ]; then printFullHelp; exit 1; fi
        getHelp $2
        exit 1
      ;;
    *)
      printUsage
      ;;
  esac
  cleanUp
}

starship $* && echo "Success."