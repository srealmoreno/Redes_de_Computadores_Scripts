#!/bin/bash
#####################################
#             UNAN-LEÓN
#  Script creado por Salvador Real
#   Redes de Computadores 2019
# Probado en:
# Debian 9,10
# Kali linux 2019.3, 2019.1
# Ubuntu 18
# Linux Mint
# Solo funciona en distribuciones basadas en Ubuntu o Debian y que utilicen apt como gestor de paquetes
####################################

Green=$(tput setaf 10)
Blue=$(tput setaf 45)
Red=$(tput setaf 9)
Yellow=$(tput setaf 11)
White=$(tput setaf 15)
Normal=$(tput sgr0)

error_fatal() {
    echo -e "${Red}Error fatal:${Normal} $1" >&2
    exit -1
}

advertencia() {
    echo -e "${Yellow}Advertencia: ${Normal}$1" >&2
}

exito() {
    echo -e "${Green}Exíto: ${Normal}$1"
}
presiona_una_tecla() {
    read -n 1 -s -r -p "Presiona cualquier tecla para continuar"
    echo ""
}
install_dependencias_gns3() {
    advertencia "Instalando dependencias de GNS3..."
    apt-get install -y make || advertencia "error en instalar make"
    apt-get install -y git || advertencia "error en instalar git"
    apt-get install -y libpcap0.8-dev || advertencia "error en instalar libpcap0.8-dev"

    if [ -d /usr/bin/python3.7 ]; then

        if [ ! -e /usr/bin/python3.5 ]; then
            ln -s /usr/bin/python3.7 /usr/bin/python3.5
        fi

        if [ ! -e /usr/bin/python3.6 ]; then
            ln -s /usr/bin/python3.7 /usr/bin/python3.6
        fi

        export PYTHONPATH=$PYTHONPATH:/usr/lib/python3.7
    fi

}

install_dependencias_docker() {
    advertencia "Instalando dependencias de Docker..."
    apt-get install -y apt-transport-https || error_fatal "error en instalar apt-transport-https"
    apt-get install -y ca-certificates || error_fatal "error en instalar ca-certificates"
    apt-get install -y curl || error_fatal "error en instalar curl"
    apt-get install -y gnupg2 || error_fatal "error en instalar gnupg2"
    apt-get install -y software-properties-common || error_fatal "error en instalar software-properties-common"
    apt-get install -y telnet || error_fatal "error en instalar telnet"
    apt-get install -y dirmngr || error_fatal "error en instalar dirmngr"
}

get_os() {
    apt-get update
    advertencia "Obteniendo información del sistema..."
    if [ -f /etc/os-release ]; then
        source /etc/os-release
    else
        apt-get install -y lsb-base lsb-release || error_fatal "error en instalar lsb-release"
        ID=$(lsb_release -is)
        ID="${ID,,}"
        VERSION_ID=$(lsb_release -rs)
        VERSION_CODENAME=$(lsb_release -cs)
        PRETTY_NAME=$(lsb_release -ds)
    fi

    if [[ "$ID" != *ubuntu* ]] && [[ "$ID" != *debian* ]]; then
        if [[ "$ID_LIKE" != *ubuntu* ]] && [[ "$ID_LIKE" != *debian* ]]; then
            error_fatal "Este script no es comaptible con $PRETTY_NAME $VERSION_ID"
        fi
    fi

    if [[ "$VERSION_CODENAME" == *sid* ]] || [[ "$VERSION_CODENAME" == *n/a* ]]; then
        advertencia "Se ha detectado una versión inestable de $PRETTY_NAME $VERSION_ID, posiblemente no funcione este script..."
        presiona_una_tecla
    fi
}

importar_a_docker() {
    advertencia "Instalando imagen $1 de Salvador"
    if [ -f "$2" ]; then
        advertencia "Importando $2"
        docker load --input "$2"
    else
        advertencia "No se pudo encontrar la imagen local... Descargando imagen $2 desde $3"
        docker pull $3
    fi && exito "Imagen $1 de Salvador instalada en docker" || advertencia "No se pudo instalar la imagen $1 de Salvador"
}

install_docker() {

    echo -e "${Blue}\tInstalando Docker"

    advertencia "Agregando repositorio"

    case "$ID" in
    *debian*)
        if (($(awk 'BEGIN {print ("'$VERSION_ID'" >= "'10'")}'))); then
            repository="buster"
        else
            repository="stretch"
        fi
        curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - || error_fatal "error al agregar la clave GPG oficial de Docker"
        echo "deb [arch=amd64] https://download.docker.com/linux/debian $repository stable" >/etc/apt/sources.list.d/docker.list
        ;;
    *ubuntu*)
        if (($(awk 'BEGIN {print ("'$VERSION_ID'" >= "'19.04'")}'))); then
            repository="disco"
        else
            if (($(awk 'BEGIN {print ("'$VERSION_ID'" >= "'18.10'")}'))); then
                repository="cosmic"
            else
                if (($(awk 'BEGIN {print ("'$VERSION_ID'" >= "'18.04'")}'))); then
                    repository="bionic"
                else
                    repository="xenial"
                fi
            fi
        fi
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - || error_fatal "error al agregar la clave GPG oficial de Docker"
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $repository stable"
        ;;
    *)
        case "$ID_LIKE" in
        *debian*)
            curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - || error_fatal "error al agregar la clave GPG oficial de Docker"
            echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" >/etc/apt/sources.list.d/docker.list
            ;;
        *ubuntu*)
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - || error_fatal "error al agregar la clave GPG oficial de Docker"

            if [ -n "$UBUNTU_CODENAME" ]; then
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable"
            else
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu disco stable"
            fi

            ;;
        *) error_fatal "Este script no es compatible con $PRETTY_NAME $VERSION_ID" ;;
        esac
        ;;
    esac && exito "Repositorio agregado" || error_fatal "Error al añadir repositorio de docker"

    advertencia "Instalando docker"

    apt-get update

    apt-get install -y docker-ce docker-ce-cli containerd.io && exito "Docker-ce Instalado con exíto" || error_fatal "error al instalar Docker-ce"

    if [ ! -n "$gns3" ]; then
        usermod -aG docker $SUDO_USER && exito "Se ha añadido a $SUDO_USER en el grupo docker con exíto" || advertencia "No se pudo agregar $SUDO_USER al grupo docker, tendrá que hacerlo manualmente"
    fi
    advertencia "Habilitando el servicio Docker"

    systemctl enable docker && exito "Servicio de docker habilitado" || advertencia "No se pudo habilitar el servicio Docker, Tendrá que habilitarlo manualmente"

    advertencia "Iniciando el servicio Docker"

    systemctl start docker && exito "Servicio de docker iniciado" || advertencia "No se pudo iniciar el servicio Docker, Tendrá que arrancarlo manualmente\n/etc/init.d/docker start?"

}
#Fin de la funcion instalar docker

update_ubridge() {
    advertencia "Instalando ubridge"
    git clone https://github.com/GNS3/ubridge.git
    cd ubridge/
    make
    make install && exito "ubridge instalado con exito" || advertencia "No se pudo instalar ubridge"
    cd ..
}

update_vpcs() {
    advertencia "Actualizando VPCS"
    git clone https://github.com/GNS3/vpcs.git
    cd vpcs/src
    ./mk.sh
    cp vpcs /usr/local/bin/ && exito "VPCS actualizado con exito" || advertencia "No se pudo actualizar VPCS"
    cd ../..
}

check_group() {
    if [ "$(grep "$1" /etc/group)" == "" ]; then
        advertencia "No existe el grupo $1\nPor favor elige 'Sí' en el siguiente dialogo"
        presiona_una_tecla
        dpkg-reconfigure $2 || advertencia "No se pudo crear el grupo"
    fi
}

update_gns3() {

    mkdir .gns3_tmp
    cd .gns3_tmp
    update_vpcs
    update_ubridge
    cd ..
    rm -rf .gns3_tmp

    advertencia "Añadiendo $SUDO_USER a los grupos necesarios"
    check_group "wireshark" "wireshark-common"
    check_group "ubridge" "ubridge"

    for i in wireshark docker ubridge; do
        usermod -aG $i $SUDO_USER && exito "Se ha añadido a $SUDO_USER en el grupo $i con exíto" || advertencia "No se pudo agregar $SUDO_USER al grupo $i, tendrá que hacerlo manualmente"
    done

}

crear_acceso_directo() {

    echo -e "${Blue}\tCreando acceso directo... ${Normal}"
    git clone https://github.com/srealmoreno/Redes_de_Computadores_Scripts.git

    cp -r Redes_de_Computadores_Scripts/files_gns3/* /usr/ || advertencia "No se pudo crear el acceso directo" && exito "Acceso directo creado exitosamente"

    rm -rf Redes_de_Computadores_Scripts

    update-icon-caches /usr/share/icons/hicolor/
    update-mime-database /usr/share/mime
   
}

install_gns3_pip() {
    echo -e "${Blue}\tInstalando Gns3 desde Python pip${Normal}"

    apt-get remove -y gns3-gui gns3-server 2>/dev/null
    rm /etc/apt/sources.list.d/gns3.list 2>/dev/null

    dpkg --add-architecture i386
    apt-get update

    apt install -y python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebsockets \
        python3-jsonschema python3-pip wireshark vinagre libc6 libpcap0.8-dev \
        libexpat1 zlib1g vpcs ubridge qemu-system-x86 qemu-kvm qemu-utils git make \
        cpulimit libvirt-daemon-system dynamips:i386 x11vnc xvfb git || error_fatal "error al instalar dependencias" && exito "Dependencias instaladas exitosamente"

    pip3 install -U pyqt5-sip || error_fatal "error al instalar gpyqt5-sip"
    pip3 install -U gns3-server || error_fatal "error al instalar gns3-server" && exito "Gns3 server instalado"
    pip3 install -U gns3-gui || error_fatal "error al instalar gns3-gui" && exito "Gns3 Gui instalado"
    update_gns3
    crear_acceso_directo

}

install_gns3() {
    echo -e "${Blue}\tInstalando Gns3"

    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F88F6D313016330404F710FC9A2FD067A2E3EF7B || error_fatal "Error al añadir clave GPG oficial de Gns3"

    case "$ID" in
    *debian*)
        case "$VERSION_CODENAME" in
        *buster*) release="bionic" ;;
        *stretch*) release="xenial" ;;
        *jessie*) release="trusty" ;;
        *) error_fatal "Este script no es comaptible con $PRETTY_NAME $VERSION_ID" ;;
        esac
        echo -e "deb http://ppa.launchpad.net/gns3/ppa/ubuntu $release main\ndeb-src http://ppa.launchpad.net/gns3/ppa/ubuntu $release main" >/etc/apt/sources.list.d/gns3.list
        ;;

    *ubuntu* | *)
        if [[ "$ID" == *ubuntu* ]] || [[ "$ID_LIKE" == *ubuntu* ]]; then
            add-apt-repository ppa:gns3/ppa
        else
            if [[ "$ID_LIKE" == *debian* ]]; then
                echo -e "deb http://ppa.launchpad.net/gns3/ppa/ubuntu bionic main\ndeb-src http://ppa.launchpad.net/gns3/ppa/ubuntu bionic main" >/etc/apt/sources.list.d/gns3.list
            else
                error_fatal "Este script no es comaptible con $PRETTY_NAME $VERSION_ID"
            fi
        fi

        ;;
    esac && exito "Repositorio agregado" || error_fatal "Error al añadir repositorio de Gns3"

    dpkg --add-architecture i386
    apt-get update
    apt-get install -y gns3-server || error_fatal "error al instalar gns3-server" && exito "Gns3 server instalado"
    apt-get install -y gns3-gui || error_fatal "error al instalar gns3-gui" && exito "Gns3 Gui instalado"
    apt-get install -y dynamips:i386

    update_gns3
}

clean_cache() {
    advertencia "Limpiando caché"
    apt-get autoremove -y
    apt-get autoclean -y
}

############## Inicio del Script ###################

if [ "$EUID" != "0" ]; then #Si no es el usuario root, se sale
    error_fatal "Debe de ejecutar el script con permisos root\nsudo $0"
fi

if [ ! -n "$SUDO_USER" ]; then
    error_fatal "Por favor inicia sesión desde un usuario diferente a root"
fi

if [ "$#" == "0" ]; then #Si no se pasa ningún argumento, instala todo
    gns3="true"
    docker="true"
    images="true"
else
    while getopts ":h :a :d :g :p :i" arg; do #a instala todo, d instala docker, g instala gns3, i instala images de salvador
        case "$arg" in
        a)
            gns3="true"
            docker="true"
            images="true"
            ;;
        g)
            if [[ -n "$pip" ]]; then
                error_fatal "Error de sintaxis, -g -p\n¿Instalar gns3 desde el repositorio y desde Python-pip?\nUso $0 [-a Instalar todo] [-d instalar docker] [-g instalar gns3] [-p instalar gns3 desde python-pip] [-i importar images de Salvador]"
            fi
            gns3="true"
            ;;
        d)
            docker="true"
            ;;
        p)
            if [[ -n "$gns3" ]]; then
                error_fatal "Error de sintaxis, -g -p\n¿Instalar gns3 desde el repositorio y desde Python-pip?\nUso $0 [-a Instalar todo] [-d instalar docker] [-g instalar gns3] [-p instalar gns3 desde python-pip] [-i importar images de Salvador]"
            fi
            pip="true"
            ;;
        i)
            images="true"
            ;;
        h)
            echo "${Yellow}Uso${Normal} $0 ${Green}[opciones] [-g -d -i]${Normal}"
            echo -e "\t${Blue} -a ${Normal}Instala todos los paquetes"
            echo -e "\t${Blue} -g ${Normal}Instala gns3 desde el repositorio oficial"
            echo -e "\t${Blue} -p ${Normal}Instala gns3 desde Python-pip (Por si -g te da problemas)(Recomendado para Kali Linux)"
            echo -e "\t${Blue} -d ${Normal}Instala docker"
            echo -e "\t${Blue} -i ${Normal}Importa imagenes ubuntu de Salvador"
            exit 1
            ;;
        *)
            error_fatal "Uso $0 [-a Instalar todo] [-d instalar docker] [-g instalar gns3] [-p instalar gns3 desde python-pip] [-i importar images de Salvador]"
            exit 1
            ;;
        esac
    done
fi

if [ -n "$docker" ] || [ -n "$gns3" ] || [ -n "$images" ] || [ -n "$pip" ]; then

    exito "Iniciando Script de instalación"

    if [ -n "$docker" ] || [ -n "$gns3" ]; then
        get_os
    fi

    if [ -n "$docker" ]; then
        install_dependencias_docker
        install_docker
    fi

    if [ -n "$gns3" ]; then
        install_dependencias_gns3
        install_gns3
    fi

    if [ -n "$pip" ]; then
        install_gns3_pip
    fi

    if [ -n "$images" ]; then
        importar_a_docker "ubuntu" "ubuntu_rdc.tar" "srealmoreno/rdc:ubuntu"
        #Descomentar para instalar la imagen con interfaz gráfica
        #importar_a_docker "ubuntu_graphic" "ubuntu_rdc_graphic.tar" "srealmoreno/rdc:ubuntu_graphic"
    fi

    if [ -n "$docker" ] || [ -n "$gns3" ] || [ -n "$pip" ]; then
        clean_cache
    fi

    exito "Instalación completada\nby: Salvador Real, Redes de computadores 2019"

else
    error_fatal "Argumentos no validos\n$*\nUso $0 [-a Instalar todo] [-d instalar docker] [-g instalar gns3] [-i importar images de Salvador]"
    exit -1
fi
