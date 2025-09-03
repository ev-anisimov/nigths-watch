/* groovylint-disable CompileStatic, DuplicateStringLiteral, LineLength, NestedBlockDepth, NoDef, UnnecessaryParenthesesForMethodCallWithClosure, VariableName */
// https://tutorials.releaseworksacademy.com/learn/building-your-first-docker-image-with-jenkins-2-guide-for-developers
if (BRANCH_NAME != 'dev') {
    _VERSION = "$BRANCH_NAME"
}
else {
    _VERSION = '1.1.0'
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// pipeline
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

pipeline {
    agent { label 'docker-builder' }
    environment {
        GIT_MESSAGE = sh(
            returnStdout: true,
            script: "git show -s --format=\" Author: %an%nDate: %ad%nMessage: %s\" ${GIT_COMMIT}"
        )
        APP_VERSION = "${_VERSION}"
        DOCKER_IMAGE = "${env.JOB_NAME}".split('/').first()
    }
    stages {
        // test
//         stage('Testing') {
//             steps {
//                 script {
//                     // build dev amd64 image with test deps
//                     sh  './build-push.sh build local'
//
//                     // run tests
//                     sh """
//                             docker run \
//                             --rm \
//                             --hostname "${DOCKER_IMAGE}" \
//                             --entrypoint "/bin/bash" \
//                             alpha.awada.systems/${DOCKER_IMAGE}:local \
//                             '/application/.venv/bin/pytest -p no:warnings --cov --cov-report term ./tests'
//                         """
//
//                     // remove test image from local storage
//                     sh  "docker image rm alpha.awada.systems/${DOCKER_IMAGE}:local"
//                 }
//             }
//         }

        // build
        stage('Build and Push to Docker registry') {
            steps {
                // perform docker login
                withCredentials([[$class: 'UsernamePasswordMultiBinding',
                        credentialsId: 'docker-private-registry',
                        usernameVariable: 'username',
                        passwordVariable: 'password']]) {
                    /* groovylint-disable-next-line GStringExpressionWithinString */
                    sh 'echo "${password}" | docker login https://alpha.awada.systems/v2 -u ${username} --password-stdin'
                }

                // build and push prod target multistage multi platform
                sh  "./build-push.sh build prod ${APP_VERSION}.${BUILD_NUMBER}"
            }
        }

        // tag
        stage('Tagging commit') {
            when { branch 'master' }
            steps {
                withCredentials([[$class: 'UsernamePasswordMultiBinding',
                        credentialsId: '4ad33704-aac6-4f91-ab33-9989e2ba28bc',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD']]) {
                    sh "git tag -a v${APP_VERSION}.${BUILD_NUMBER} -m 'Jenkins'"
                    sh "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/awada-systems/${DOCKER_IMAGE} --tags"
                }
            }
        }
    }

    // post actions
    post {
        // prepare notification header
        always {
            wrap([$class: 'BuildUser']) {
                script {
                    notificationBody = """
                        Build <a href="$JOB_URL">$JOB_NAME</a>: #<a href="$BUILD_URL">${APP_VERSION}.${BUILD_NUMBER}</a> - ${currentBuild.currentResult}
                        ------ Started by ----------
                        User: ${env.BUILD_USER}
                        ------ Last commit ---------
                        ${GIT_MESSAGE}
                        ----------------------------
                    """
                }
            }
            // spit to log
            println notificationBody
        }
    }
}
