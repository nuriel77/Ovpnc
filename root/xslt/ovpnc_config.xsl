<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:ovpnc="urn:ovpnc"
  version="1.0">

  <xsl:template match="/">
     <html>
	   <head>
		<title>Ovpnc Configuration</title>
		<!-- JS and CSS includes -->
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/jquery-latest.js</xsl:attribute>
		</script>
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/json2.js</xsl:attribute>
		</script>
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/config.js</xsl:attribute>
		</script>
		<link rel="stylesheet" type="text/css">
		  <xsl:attribute name="href">/static/css/config.css</xsl:attribute>
		</link>
	   </head>
       <body>
		<div class="container">
		 <!-- main form -->
	     <form name="configuration" id="conf" method="POST" action="/api/configuration">
		   <!-- loop each node -->
		   <xsl:for-each select="Nodes/Node">
			 <!-- submit and reset buttons -->
		     <p><input type="submit" name="Send" /><input type="reset" /></p>
	         <table colspacing="0" colspan="0">
			  <!--
				   these two are external 
				   to the .conf file that
				   will be created with all 
				   the rest of the params
			  -->
		      <tr class="odd">
		        <td class="ConfigKeys">Node Name:</td>
		        <td>
	  			  <input type="text" name="Name" class="file"><xsl:attribute name="value"><xsl:value-of select="Name"/></xsl:attribute></input>
			    </td>
		      </tr>
		      <tr class="odd">
		        <td class="ConfigKeys">Config File:</td>
		        <td>
				  <input type="text" name="ConfigFile" class="file">
                    <xsl:attribute name="value"><xsl:value-of select="ConfigFile"/></xsl:attribute>
				  </input>
			    </td>
		      </tr>

			  <!-- parse through Directives -->
		      <xsl:for-each select="Directives/Group/Directive">
  		       <xsl:variable name="configItem" select="Name"/>
		        <tr class="odd">
				  <xsl:attribute name="id"><xsl:value-of select="Name"/></xsl:attribute>
				  <!-- get/set the group id of this param -->
				  <xsl:attribute name="group"><xsl:value-of select="../@id"/></xsl:attribute>
				  <!-- get/set the status of this param -->
				  <xsl:attribute name="status"><xsl:value-of select="@status"/></xsl:attribute>
				  <!--
						To this tr we add attrib "alone" if this
						element has no parameters
				  -->
			      <xsl:choose>
			       <xsl:when test="Params">
			       </xsl:when>
			       <xsl:otherwise>
			        <xsl:attribute name="alone">on</xsl:attribute>
			       </xsl:otherwise>
    		      </xsl:choose>
			      <td class="control"><xsl:attribute name="id"><xsl:value-of select="Name"/></xsl:attribute></td>

			      <td class="ConfigKeys">
					<!-- 
						 ConfigKeys colum, we check if this is "alone" type - no parameters,
						 we make it as a readonly input
					-->
			        <xsl:choose>
			          <xsl:when test="Params">
					    <xsl:value-of select="Name"/>
			          </xsl:when>
			          <xsl:otherwise>
				        <input class="hideme" type="text" readonly="readonly">
						  <xsl:attribute name="value"><xsl:value-of select="Name"/></xsl:attribute>
						  <xsl:attribute name="name"><xsl:value-of select="Name"/></xsl:attribute>
						  <xsl:attribute name="parent"><xsl:value-of select="Name"/></xsl:attribute>
						</input>
			          </xsl:otherwise>
    		        </xsl:choose>
				  </td>
			  	  <xsl:choose>
	
	  				<!-- parse through Params -->
					<xsl:when test="Params">
					  <xsl:for-each select="Params">
						<xsl:for-each select="*">

						  <!-- Define variables -->
						  <xsl:variable name="local" select="local-name()"/>
						  <xsl:variable name="current" select="."/>
			       	  	  <td><span class="msg" ><xsl:value-of select="$local"/></span></td>
						  <xsl:choose>
							<xsl:when test="$local = 'ManagementPort' or $local = 'ServerPort'">
                              <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
								  <!-- Define variables from xsd schema -->
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num" >
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
	                                <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
	                                <xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:if test="$required = 0">
		                              <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
									</xsl:if>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
                              </td>
                            </xsl:when>
							<!-- MaxClients -->
							<xsl:when test="$local = 'MaxClients'">
                              <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
								  <!-- Define variables from xsd schema -->
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:if test="$required = 0">
		                              <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
									</xsl:if>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
                              </td>
                            </xsl:when>
							<!-- KeepAlivePoll -->
						    <xsl:when test="$local = 'KeepAlivePoll'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = '0'">
		                              <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
									</xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- KeepAliveDead-->
						    <xsl:when test="$local = 'KeepAliveDead'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- ConnectFreqNew -->
						    <xsl:when test="$local = 'ConnectFreqNew'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- Connect-Freq-Sec -->
						    <xsl:when test="$local = 'ConnectFreqSec'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- Mute and Process-Prio -->
						    <xsl:when test="$local = 'Mute' or $local='Process-Prio'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'StatusSec'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- Verb -->
						    <xsl:when test="$local = 'Verb' or $local='ProcessPrio'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="elementType" select="@type"/>
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
	                                <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- TlsMode -->
						    <xsl:when test="number($current) or $local = 'TlsMode'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
 						          <xsl:variable name="elementType" select="@type"/>
								  <input type="text" class="num">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
								    <xsl:attribute name="class">num</xsl:attribute>
							        <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
								  </input>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
								</xsl:for-each>
							  </td>
						    </xsl:when>
							<!-- PushString -->
						    <xsl:when test="$local='PushString'">	
						      <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <input type="text" class="file">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
                                    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							      </input>								
								</xsl:for-each>
						      </td>
						    </xsl:when>
							<!-- Many types... -->
						    <xsl:when test="$local='StatusFile' 
										or $local='CrlFile'
										or $local='ChrootDir'
										or $local='PoolFile'
										or $local='ClientDir'
										or $local='LogFile'
										or $local='AuthScript'
										or $local='Ca'
										or $local='Dh'
										or $local='Key'
										or $local='Certificate'">
						      <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <input type="text" class="file">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							      </input>								
								</xsl:for-each>
						      </td>
						    </xsl:when>
							<!-- TlsKey -->
						    <xsl:when test="$local='TlsKey'">
						      <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <input type="text" class="file">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							      </input>								
								</xsl:for-each>
						      </td>
						    </xsl:when>
							<!-- PoolBegin and PoolEnd -->
							<xsl:when test="$local='PoolEnd' or $local='PoolBegin'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <input type="text" class="file">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
                                    <xsl:attribute name="class">ip</xsl:attribute>
								    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							      </input>								
								</xsl:for-each>
						      </td>
						    </xsl:when>
							<!-- ManagementIP, VirtualNetmask, VPNServer, VirtualIP -->
						    <xsl:when test="$local = 'ManagementIP'
										 or $local = 'VirtualNetmask'
										 or $local='VPNServer'
										 or $local='VirtualIP'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input>
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
                                    <xsl:attribute name="value"><xsl:value-of select="$current"/></xsl:attribute>
                                    <xsl:attribute name="class">ip</xsl:attribute>
									<xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
								</xsl:for-each>
                              </td> 
						    </xsl:when>
						    <xsl:when test="$local = 'Bool'">
						      <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
                                  <input>
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
                                    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
                                    <xsl:attribute name="class">num</xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
                                  </input>
								</xsl:for-each>
                              </td> 
						    </xsl:when>
						    <xsl:when test="$local = 'Protocol'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
							        <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name='Protocolcols']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
									  <xsl:variable name="selectedItem" select="."/>
                                      <option>
                                        <xsl:attribute name="value"><xsl:value-of select="$selectedItem"/></xsl:attribute>
                                        <xsl:if test="$current = $selectedItem">
                                          <xsl:attribute name="selected"></xsl:attribute>
                                        </xsl:if>
                                        <xsl:value-of select="."/>
                                      </option>
							        </xsl:for-each>
								  </select>
								</xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- Cipher -->
						    <xsl:when test="$local = 'Cipher'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="test"><xsl:value-of select="$current"/></xsl:attribute>
							        <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name='CipherType']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
									  <xsl:variable name="selectedItem" select="."/>
							  	      <option>
										<xsl:attribute name="value"><xsl:value-of select="$selectedItem"/></xsl:attribute>
										<xsl:if test="$current = $selectedItem">
										  <xsl:attribute name="selected"></xsl:attribute>
										</xsl:if>
										<xsl:value-of select="$selectedItem"/>
									  </option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- CompLzo -->
						    <xsl:when test="$local = 'CompLzo'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name='CompLzo']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
									  <xsl:variable name="selectedItem" select="."/>
							  	      <option>
										<xsl:attribute name="value"><xsl:value-of select="$selectedItem"/></xsl:attribute>
										<xsl:if test="$current = $selectedItem">
                                          <xsl:attribute name="selected"></xsl:attribute>
                                        </xsl:if>
										<xsl:value-of select="."/>
									  </option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- Device -->
						    <xsl:when test="$local = 'Device'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name='DeviceType']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
									  <xsl:variable name="selectedItem" select="."/>
							  	      <option>
										<xsl:attribute name="value"><xsl:value-of select="$selectedItem"/></xsl:attribute>
                                        <xsl:if test="$current = $selectedItem">
                                          <xsl:attribute name="selected"></xsl:attribute>
                                        </xsl:if>
										<xsl:value-of select="."/>
									  </option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- ScriptMethod -->
						    <xsl:when test="$local = 'ScriptMethod'">
							  <td>
                                <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpnc_config.xsd')/xsd:schema/xsd:simpleType[@name='ScriptMethods']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
									  <xsl:variable name="selectedItem" select="."/>
							  	      <option>
										<xsl:attribute name="value"><xsl:value-of select="$selectedItem"/></xsl:attribute>
                                        <xsl:if test="$current = $selectedItem">
                                          <xsl:attribute name="selected"></xsl:attribute>
                                        </xsl:if>
										<xsl:value-of select="."/>
									  </option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>
							<!-- GroupName, UserName -->
						    <xsl:when test="$local = 'GroupName' or $local = 'UserName'">
							  <td>
							      <input type="text" class="file">
								    <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
								  </input>
							  </td>  
						    </xsl:when>

							<xsl:otherwise>
				          	  <td>
							    <input type="text" readonly="readonly">
								  <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
								</input>
							  </td>
							</xsl:otherwise>
						  </xsl:choose>
			  	        </xsl:for-each>
			  	      </xsl:for-each>
					</xsl:when>
					<xsl:otherwise>
					</xsl:otherwise>
				</xsl:choose>
			  </tr>
		    </xsl:for-each>
		  </table>
		  <hr />
		</xsl:for-each>
	   </form>
       </div>
   	  </body>
     </html>
   </xsl:template>
</xsl:stylesheet>
