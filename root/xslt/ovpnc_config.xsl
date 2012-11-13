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
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/jquery-latest.js</xsl:attribute>
		</script>
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/json2.js</xsl:attribute>
		</script>
		<script type="text/javascript">
		  <xsl:attribute name="src">/static/js/ovpn.js</xsl:attribute>
		</script>
		<style>
			html, body{ font-family:arial; font-size:12px; }
			.container { padding:5px; width:900px; margin:0 auto; }
			.ConfigKeys { font-size:13px; }	
			.odd { background-color:eeeeff; }	
			.num { width:45px; border:1px solid lightgray; }	
			.ip { width:105px; border:1px solid lightgray; }	
			.file { width:225px; border:1px solid lightgray; }	
			.msg { font-size:10px; font-style:italic; color:gray; }
			.disb { cursor:pointer; }
			.rmv { margin-right:5px; float:right; }
			.mySelect { border:none; min-width:50px; }
			.control { min-width:65px; }
			.input { text-align:right; }
			.hideme {
				padding:0px;
				text-decoration: none;
				margin:0px;
				background-color:#eeeeff;
				font-size:13px;
				border:0;
				text-align:left; 
			}
		</style>
	   </head>
       <body>
		<div class="container">
	     <form name="configuration" id="conf" method="POST" action="/api/config/update">
		   <xsl:for-each select="Nodes/Node">
		     <p><input type="submit" name="Send" /><input type="reset" /></p>
	         <table colspacing="0" colspan="0">
		      <tr class="odd">
		        <td class="ConfigKeys">Node Name:</td>
		        <td>
	  			  <input type="text" name="Name" class="file"><xsl:attribute name="value"><xsl:value-of select="Name"/></xsl:attribute></input>
			    </td>
		      </tr>
		      <tr class="odd">
		        <td class="ConfigKeys">Config File:</td>
		        <td>
				  <input type="text" name="Config-File" class="file">
                    <xsl:attribute name="value"><xsl:value-of select="Config-File"/></xsl:attribute>
				  </input>
			    </td>
		      </tr>
			  <tr></tr>

			  <!-- parse through Directives -->
		      <xsl:for-each select="Directives/Group/Directive">
  		       <xsl:variable name="configItem" select="Name"/>
		        <tr class="odd"><xsl:attribute name="id"><xsl:value-of select="Name"/></xsl:attribute>
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
						  <xsl:variable name="it" select="0"/>
			       	  	  <td><span class="msg" ><xsl:value-of select="$local"/></span></td>
						  <xsl:choose>
							<xsl:when test="$local = 'Management-Port' or $local = 'Server-Port'">
                              <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
                              </td>
                            </xsl:when>
							<xsl:when test="$local = 'Max-Clients'">
                              <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
                              </td>
                            </xsl:when>
						    <xsl:when test="$local = 'KeepAlive-Poll'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'KeepAlive-Dead'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Connect-Freq-New'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Connect-Freq-Sec'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Mute'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Status-Sec'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Verb'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:minInclusive/@value">
							        <span class="msg"><xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                  <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name=$elementType]/xsd:restriction[@base='xsd:integer']/xsd:maxInclusive/@value">
							        <span class="msg"> - <xsl:value-of select="."/></span>
                                  </xsl:for-each>
                                </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="number($current) or $local = 'Tls-Mode'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
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
								</xsl:for-each>
							  </td>
						    </xsl:when>

						    <xsl:when test="$local='Push-String'">	
						      <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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

						    <xsl:when test="$local='Status-File' or $local='Ca' or $local='Dh' or $local='Key' or $local='Certificate'">
						      <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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

						    <xsl:when test="$local='Tls-Key'">
						      <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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

						    <xsl:when test="$local = 'Management-IP' or $local = 'Virtual-Netmask' or $local='VPN-Server' or $local='Virtual-IP'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
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
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
							        <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name='Protocolcols']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
							  	      <option><xsl:value-of select="."/></option>
							        </xsl:for-each>
								  </select>
								</xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Cipher'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name='CipherType']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
							  	      <option><xsl:value-of select="."/></option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>
						    <xsl:when test="$local = 'Comp-Lzo'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name='CompLzo']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
							  	      <option><xsl:value-of select="."/></option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>

						    <xsl:when test="$local = 'Device'">
							  <td>
                                <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:element[@name='Params']/xsd:complexType/xsd:sequence/xsd:choice/xsd:element[@name=$local]">
 						          <xsl:variable name="required" select="@minOccurs"/>
								  <select class="mySelect">
									<xsl:if test="$required = 0">
                                      <xsl:attribute name="required"><xsl:value-of select="$required"/></xsl:attribute>
                                    </xsl:if>
									<xsl:attribute name="name"><xsl:value-of select="$configItem"/></xsl:attribute>
									<xsl:attribute name="parent"><xsl:value-of select="$local"/></xsl:attribute>
								    <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
							        <xsl:for-each select="document('ovpn.xsd')/xsd:schema/xsd:simpleType[@name='DeviceType']/xsd:restriction[@base='xsd:string']/xsd:enumeration/@value">
							  	      <option><xsl:value-of select="."/></option>
							        </xsl:for-each>
								  </select>
							    </xsl:for-each>
							  </td>  
						    </xsl:when>

						    <xsl:when test="$local = 'Group-Name' or $local = 'User-Name'">
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
<!--						<input type="checkbox" class="checkBox" ref="off">
						  <xsl:attribute name="id"><xsl:value-of select="$configItem"/></xsl:attribute>
						  <xsl:attribute name="ref"><xsl:value-of select="."/></xsl:attribute>
						</input>
						<span class="msg"><xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>disable</span>
-->
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
