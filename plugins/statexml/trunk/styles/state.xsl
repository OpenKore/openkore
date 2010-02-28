<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html"
	doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
	doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
/>

<xsl:template match="/state">
	<head>
		<title>
			<xsl:choose>
				<xsl:when test="char"><xsl:value-of select="char/name"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="connectionState"/></xsl:otherwise>
			</xsl:choose>
			- OpenKore
		</title>
		<link rel="stylesheet" type="text/css" href=".statexml-styles/global.css"/>
		<link rel="stylesheet" type="text/css" href=".statexml-styles/default.css" title="Default"/>
	</head>
	<body id="state-body">
		<div id="header">
			<xsl:choose>
				<xsl:when test="char">
					<div id="char-name"><xsl:value-of select="char/name"/></div>
					<div id="char-info">
						<xsl:value-of select="char/lv"/>/<xsl:value-of select="char/lv_job"/>
						<xsl:text> </xsl:text>
						<xsl:value-of select="char/job"/>
						<xsl:text> </xsl:text>
						<xsl:value-of select="char/sex"/>
					</div>
					<div id="char-statuses">
						<xsl:for-each select="char/statuses/status">
							<span><xsl:value-of select="."/></span>
							<xsl:text> </xsl:text>
						</xsl:for-each>
					</div>
				</xsl:when>
				<xsl:otherwise>
					<div id="connection-state"><xsl:value-of select="connectionState"/></div>
				</xsl:otherwise>
			</xsl:choose>
		</div>
		
		<div id="info">
			<xsl:if test="char">
				<div class="split"><div id="hp-info" class="gauge">
					HP: <xsl:value-of select="char/hp"/> / <xsl:value-of select="char/hp_max"/>
					<div>
						<xsl:attribute name="style">width:<xsl:value-of select="floor(100 * char/hp div char/hp_max)"/>%;</xsl:attribute>
					</div>
				</div></div>
				<div class="split"><div id="sp-info" class="gauge">
					SP: <xsl:value-of select="char/sp"/> / <xsl:value-of select="char/sp_max"/>
					<div>
						<xsl:attribute name="style">width:<xsl:value-of select="floor(100 * char/sp div char/sp_max)"/>%;</xsl:attribute>
					</div>
				</div></div>
				<div class="split"><div id="exp-info" class="gauge">
					EXP: <xsl:value-of select="char/exp"/> / <xsl:value-of select="char/exp_max"/>
					<div>
						<xsl:attribute name="style">width:<xsl:value-of select="floor(100 * char/exp div char/exp_max)"/>%;</xsl:attribute>
					</div>
				</div></div>
				<div class="split"><div id="jobexp-info" class="gauge">
					Job: <xsl:value-of select="char/exp_job"/> / <xsl:value-of select="char/exp_job_max"/>
					<div>
						<xsl:attribute name="style">width:<xsl:value-of select="floor(100 * char/exp_job div char/exp_job_max)"/>%;</xsl:attribute>
					</div>
				</div></div>
				<div class="split"><div id="weight-info" class="gauge">
					Weight: <xsl:value-of select="char/weight"/> / <xsl:value-of select="char/weight_max"/>
					<div>
						<xsl:attribute name="style">width:<xsl:value-of select="floor(100 * char/weight div char/weight_max)"/>%;</xsl:attribute>
					</div>
				</div></div>
			</xsl:if>
		</div>
		
		<div id="actorlist">
			<table>
				<xsl:for-each select="actors/actor">
					<tr>
						<xsl:attribute name="class"><xsl:value-of select="actorType"/></xsl:attribute>
						<th><xsl:value-of select="name"/></th>
						<td><xsl:value-of select="actorType"/></td>
						<td><xsl:value-of select="x"/><xsl:text> </xsl:text><xsl:value-of select="y"/></td>
					</tr>
				</xsl:for-each>
			</table>
		</div>
		
		<div id="map">
			<div id="map-title">
				<xsl:value-of select="field/name"/><xsl:text> </xsl:text>
				<xsl:value-of select="char/x"/><xsl:text> </xsl:text><xsl:value-of select="char/y"/>
			</div>
			<xsl:if test="field/image">
				<div id="map-image">
					<img>
						<xsl:attribute name="src"><xsl:value-of select="field/image"/></xsl:attribute>
						<xsl:attribute name="alt"><xsl:value-of select="field/name"/></xsl:attribute>
					</img>
					<div id="map-char">
						<xsl:attribute name="style">left:<xsl:value-of select="char/x"/>px; bottom:<xsl:value-of select="char/y"/>px;</xsl:attribute>
					</div>
				</div>
			</xsl:if>
		</div>
		
		<div id="footer">
			<div id="application-name">
				<xsl:value-of select="application/name"/><xsl:text> </xsl:text><xsl:value-of select="application/version"/>
			</div>
			<div id="application-link"><a>
				<xsl:attribute name="href"><xsl:value-of select="application/website"/></xsl:attribute>
				<xsl:value-of select="application/website"/>
			</a></div>
		</div>
	</body>
</xsl:template>

</xsl:stylesheet>
