# Validate that the username and password are set
if [[ -z "$GALAXYUSER" || -z "$GALAXYPASSWORD" ]]; then
	echo "The GALAXY_USER and GALAXY_PASSWORD environment variables must be set before using vagrant up." 1>&2
	echo "Please export them from your .bashrc file or  set them in the ./config/config.yml" 1>&2

	exit 0
fi

# Parse the public id from e-mail by discarding the domain portion
IFS="@"
set -- $GALAXYUSER
if [ "${#@}" -ne 2 ];then
	echo "The GALAXY_USER parameter must be an e-mail address." 1>&2
	echo "$GALAXYUSER is invalid!" 1>&2
	exit 0
fi

# Validate password is at least 6 characters
if [ $(echo ${#GALAXYPASSWORD}) -lt 6 ]; then
	echo "The GALAXY_PASSWORD parameter must be 6 characters long." 1>&2
	exit 0
fi
