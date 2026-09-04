################################################################################
#
# openipc-lldp
#
################################################################################

OPENIPC_LLDP_VERSION = 0.2.1
OPENIPC_LLDP_SITE = $(BR2_EXTERNAL_GENERAL_PATH)/package/openipc-lldp
OPENIPC_LLDP_SITE_METHOD = local

define OPENIPC_LLDP_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Os \
		-o $(@D)/openipc-lldp \
		$(@D)/openipc-lldp.c
endef

define OPENIPC_LLDP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(@D)/openipc-lldp \
		$(TARGET_DIR)/usr/bin/openipc-lldp

	$(INSTALL) -D -m 0755 \
		$(@D)/S55openipc-lldp \
		$(TARGET_DIR)/etc/init.d/S55openipc-lldp
endef

$(eval $(generic-package))
