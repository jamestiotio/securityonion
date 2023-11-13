#!/bin/bash

source /usr/sbin/so-common
source /root/SecurityOnion/setup/so-functions

stig_dir=/root/stig
setup_log=$stig_dir/stig-setup.log

while [[ $# -gt 0 ]]; do
    arg="$1"
    shift
    case "$arg" in
        "--cat1" )
            cat1=true
            ;;
        "--cat2" )
            cat2=true
            ;;
        "--cat3" )
            cat3=true
            ;;
        * )
            echo "No option $arg"
            exit 1
    esac
done

apply_cat1(){
    mkdir -p $stig_dir
    title "Applying CAT1 STIGs not applied by OSCAP"
    title "Setting Ctrl-Alt-Del action to none"
    info "per OSCAP rule id: xccdf_org.ssgproject.content_rule_disable_ctrlaltdel_burstaction"
    if ! grep -q "^CtrlAltDelBurstAction=none$" /etc/systemd/system.conf; then
        sed -i 's/#CtrlAltDelBurstAction=reboot-force/CtrlAltDelBurstAction=none/g' /etc/systemd/system.conf
        logCmd "grep CtrlAltDelBurstAction /etc/systemd/system.conf"
    fi

    title "Setting ctrl-alt-del.target to masked or /dev/null"
    info "per OSCAP rule id: xccdf_org.ssgproject.content_rule_disable_ctrlaltdel_reboot"
    if systemctl is-enabled ctrl-alt-del.target | grep -q masked; then
        info "ctrl-alt-del.target is already masked"
    else
        info "Redirecting ctrl-alt-del.target symlink to /dev/null"
        logCmd "ln -sf /dev/null /etc/systemd/system/ctrl-alt-del.target"
    fi

    title "Remove nullok from password-auth & system-auth"
    info "per OSCAP rule id: xccdf_org.ssgproject.content_rule_no_empty_passwords"
    sed -i 's/ nullok//g' /etc/pam.d/password-auth
    sed -i 's/ nullok//g' /etc/pam.d/system-auth

    title "Setting PermitEmptyPasswords no in /etc/ssh/sshd_config"
    info "per OSCAP rule id: xccdf_org.ssgproject.content_rule_sshd_disable_empty_passwords"
    if grep -q "^#PermitEmptyPasswords no$" /etc/ssh/sshd_config; then
        sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
        logCmd "grep PermitEmptyPasswords /etc/ssh/sshd_config"
    else
        logCmd "echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config"
    fi

    title "Setting PermitUserEnvironment no in /etc/ssh/sshd_config"
    info "per STIG rule id: SV-248650r877377"
    if grep -q "^#PermitUserEnvironment no$" /etc/ssh/sshd_config; then
        sed -i 's/#PermitUserEnvironment no/PermitUserEnvironment no/g' /etc/ssh/sshd_config
        logCmd "grep PermitUserEnvironment /etc/ssh/sshd_config"
    else
        logCmd "echo 'PermitUserEnvironment no' >> /etc/ssh/sshd_config"
    fi

    title "Setting localpkg_gpgcheck=1"
    info "per OSCAP rule id: xccdf_org.ssgproject.content_rule_ensure_gpgcheck_local_packages"
    if [ ! -f /opt/so/saltstack/local/salt/repo/client/files/oracle/yum.conf.jinja ]; then
        logCmd "cp /opt/so/saltstack/default/salt/repo/client/files/oracle/yum.conf.jinja /opt/so/saltstack/local/salt/repo/client/files/oracle/yum.conf.jinja"
    fi
    if ! grep -q "^localpkg_gpgcheck=1$" /opt/so/saltstack/local/salt/repo/client/files/oracle/yum.conf.jinja; then
        echo 'localpkg_gpgcheck=1' >> /opt/so/saltstack/local/salt/repo/client/files/oracle/yum.conf.jinja
        logCmd "grep localpkg_gpgcheck /opt/so/saltstack/local/salt/repo/client/files/oracle/yum.conf.jinja"
    fi
    if ["$cat2" != true]; then
        title "Running custom OSCAP profile to remediate only CAT1 STIGs"
        logCmd "oscap xccdf eval --remediate --profile xccdf_org.ssgproject.content_profile_stig --results $stig_dir/resultscat1.xml $stig_dir/ssg-SOS-ol9-ds-updated-CAT1.xml"
    fi
    # title "Running OSCAP scan to verify application of STIGs"
    # info "The profile used to verify application of STIGs includes ALL CAT1 / CAT2 / CAT3 STIGs. It is expected that this report has only CAT1s as passing."
    # info "You can review the report post-CAT1-oscap-report.html in a web browser."
    # logCmd "oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results post-CAT1-oscap-results.xml --report post-CAT1-oscap-report.html ssg-ol9-ds.xml"
}

apply_cat2(){
    title "Applying CAT2 STIGs not applied by OSCAP"
    info "Removing aide package from local repo to prevent installation. Removed in 2.4.30"
    logCmd "rm -f /nsm/repo/aide-0.16-100.el9.x86_64.rpm"

    title "Running custom OSCAP profile to remediate both CAT1 & CAT2 STIGs"
    logCmd "oscap xccdf eval --remediate --profile xccdf_org.ssgproject.content_profile_stig --results $stig_dir/resultscat2.xml $stig_dir/ssg-SOS-ol9-ds-updated-CAT1-CAT2.xml"

    title "Running OSCAP scan to verify application of STIGs"
    info "The profile used to verify application of STIGs includes ALL CAT1 / CAT2 / CAT3 STIGs. It is expected that this report has CAT1s & some CAT2s as passing."

    info "You can review the report post-CAT1-CAT2-oscap-report.html in a web browser."
    logCmd "oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results $stig_dir/post-CAT1-CAT2-oscap-results.xml --report $stig_dir/post-CAT1-CAT2-oscap-report.html /usr/share/xml/scap/ssg/content/ssg-ol9-ds.xml"

}

if [ "$cat1" = true ] && [ "$cat2" = false ]; then
    apply_cat1
elif [ "$cat1" = true ] && [ "$cat2" = true ]; then
    apply_cat1
    apply_cat2
else
    echo "No category selected"
fi







