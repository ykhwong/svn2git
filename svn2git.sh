IFS='
'
CURDIR=/d
BASEDIR=/d/repos
GITDIR=/d/gitrepo
GITTMPDIR=/d/sop
SVNDIR=/d/svnrepo
TMPFILE=/d/tmp.txt
GITURL=https://USERNAME@bitbucket.org/USERNAME/REPO.git
SVNURL=file:///C:/Users/USERNAME/repos/repos/

if [ -d ${GITDIR} ]; then
	rm -rf ${GITDIR}
fi

if [ -d ${GITTMPDIR} ]; then
	rm -rf ${GITTMPDIR}
fi

git clone ${GITURL}
RETCODE=$?
if [ $RETCODE -ne 0 ]; then
	exit $RETCODE
fi

mv ${GITTMPDIR} ${GITDIR}
cd ${GITDIR}
git config credential.helper store

cd $CURDIR

if [ -d ${SVNDIR} ]; then
	rm -rf ${SVNDIR}
fi

mkdir ${SVNDIR}
cd ${SVNDIR}
svn co ${SVNURL}

SVNDIR=${SVNDIR}/repos

rm ${TMPFILE}
touch ${TMPFILE}

cd ${BASEDIR}
FLAG=0
R_REV=0
R_MSG=0
R_USR=0
for sth in `svn log --verbose -r 1:760`
do
	echo $sth
	if [ `echo $sth | egrep -c '^\-\-\-\-\-\-'` -gt 0 ]; then
		if [ $FLAG -eq 1 ]; then
			cd $SVNDIR
			svn up -${R_REV}
			cd $GITDIR

			for sth2 in `cat ${TMPFILE}`
			do
				if [ `echo $sth2 | egrep -c '^   A '` -ne 0 ]; then
					TMPVAR=`echo $sth2 | sed 's#^   A /*##' | sed 's/ .*//'`
					
					if [ -d ${SVNDIR}/${TMPVAR} ]; then
						mkdir -p ${TMPVAR}
					else
						mkdir -p `dirname ${TMPVAR}`
					fi
					cp -rfp $SVNDIR/${TMPVAR} ${TMPVAR}

					TMPCNT=0
					if [ -d "${SVNDIR}/${TMPVAR}" ]; then
						for mm in `find ${TMPVAR} -type f`
						do
							if [ `echo $mm | grep -c "\/"` -ne 0 ]; then
								continue
							else
								TMPCNT=1
								break
							fi
						done
					fi
					if [ ${TMPCNT} -eq 0 ]; then
						touch ${TMPVAR}/.tmpn3n 2>/dev/null
					fi
					
					git add ${TMPVAR}
					continue
				fi
				if [ `echo $sth2 | egrep -c '^   M '` -ne 0 ]; then
					TMPVAR=`echo $sth2 | sed 's#^   M /*##' | sed 's/ .*//'`
					cp -rfp $SVNDIR/${TMPVAR} ${TMPVAR}
					continue
				fi
				if [ `echo $sth2 | egrep -c '^   D '` -ne 0 ]; then
					TMPVAR=`echo $sth2 | sed 's#^   D /*##' | sed 's/ .*//'`
					rm -rf ${TMPVAR}
					git rm -f ${TMPVAR}
					continue
				fi
			done

			if [ `echo ${R_MSG} | egrep -c '^0'` -ne 0 ]; then #commit
				git commit -a -m "SVN ${R_REV}"
				RETCODE=$?
				if [ $RETCODE -ne 0 ]; then
					git add -A ## TO-DO: better option?
					git commit -a -m "SVN ${R_REV}"
				fi
			else # commit with a message
				git commit -a -m "`echo ${R_MSG} | iconv -f euc-kr -t utf-8`"
				RETCODE=$?
				if [ $RETCODE -ne 0 ]; then
					git add -A ## TO-DO: better option?
					git commit -a -m "`echo ${R_MSG} | iconv -f euc-kr -t utf-8`"
				fi
			fi
			git push
			
		fi
		FLAG=0
		R_MSG=0
		R_REV=0
		R_USR=0
		rm ${TMPFILE}
		continue
	fi
	if [ `echo $sth | egrep -c '\S'` -eq 0 ]; then
		continue
	fi
	if [ `echo $sth | egrep -c '^Changed paths:'` -ne 0 ]; then
		continue
	fi
	if [ `echo $sth | egrep -c '^   (A|M|D) '` -ne 0 ]; then
		echo $sth >>${TMPFILE}
		continue
	fi

	if [ $FLAG -eq 1 ]; then
		R_MSG=${sth}
		continue
	fi
	if [ `echo $sth | egrep -c '^r[0-9]+.+line'` -gt 0 ]; then
		FLAG=1
		R_REV=`echo $sth | awk '{print $1}'`
		R_USR=`echo $sth | awk '{print $2}'`
	fi
done

cd ${CURDIR}

