<?xml version="1.0" encoding="utf-8"?>
<!--
 -  Copyright (c)2008-2010 Mark Logic Corporation. All Rights Reserved.
 -
 -  Licensed under the Apache License, Version 2.0 (the "License");
 -  you may not use this file except in compliance with the License.
 -  You may obtain a copy of the License at
 -
 -  http//www.apache.org/licenses/LICENSE-2.0
 -
 -  Unless required by applicable law or agreed to in writing, software
 -  distributed under the License is distributed on an "AS IS" BASIS,
 -  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 -  See the License for the specific language governing permissions and
 -  limitations under the License.
 -
 -  The use of the Apache License does not indicate that this project is
 -  affiliated with the Apache Software Foundation.
 -->
<!-- xslt-2 would be nice, but browsers do not support it yet -->
<xsl:stylesheet version="1.0"
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
      method="xml"
      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
      doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
      />

  <!-- text -->
  <xsl:template match="text()">
    <xt><xsl:value-of select="."/></xt>
  </xsl:template>

  <!-- comments -->
  <xsl:template match="comment()">
    <xc>&lt;!--<xsl:value-of select="."/>--&gt;</xc>
  </xsl:template>

  <!-- attributes -->
  <xsl:template match="@*">
    <xa><xsl:text> </xsl:text><xsl:value-of
    select="name()"/>="<xv><xsl:value-of select="."/></xv>"</xa>
  </xsl:template>

  <xsl:template match="processing-instruction()">
    <!-- omit any PI for this xsl -->
    <xsl:if test="name(.) != 'xml-stylesheet'
                  or not(contains(., 'href=&quot;xml-tree.xsl'))">
    <xp>&lt;?<xsl:value-of select="name()"/><xsl:text> </xsl:text><xsl:value-of
    select="."/>?&gt;</xp>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*">
      <!-- NB - careful with whitespace in here! -->
      <!-- start tag, attribute nodes, and namespaces -->
      <xsl:variable name="node-count" select="count(node())"/>
      <xsl:variable name="is-tree" select="$node-count > 1"/>
      <xsl:choose><xsl:when test="$is-tree"><xw>—</xw></xsl:when><xsl:when test="not(parent::*)">&#160;</xsl:when><xsl:otherwise></xsl:otherwise></xsl:choose>
      <xe>&lt;<xsl:value-of
      select="name()"/><xsl:apply-templates
      select="@*"/><xsl:variable name="ns"
      select="namespace::*"/><xsl:variable name="pns"
      select="../namespace::*"/><xsl:if test="$ns"><xsl:for-each
      select="$ns[not(. = $pns)]"><xsl:variable name="prefix"
      select="local-name(.)"/><xsl:text> </xsl:text><xn>xmlns<xsl:if
      test="$prefix">:<xsl:value-of
      select="$prefix"/></xsl:if></xn>="<xv><xsl:value-of
      select="string()"/></xv>"</xsl:for-each></xsl:if>
      <!-- empty? -->
      <xsl:choose>
        <xsl:when
            test="0 = $node-count">/&gt;</xsl:when>
        <!-- close start tag and proceed -->
        <xsl:otherwise>&gt;<xsl:choose>
        <!-- any children? -->
        <xsl:when test="$is-tree">
          <ul>
            <xsl:for-each select="node()">
              <xsl:if test="not(self::text()) or normalize-space(.)">
                <li><xsl:if test="count(node()) &lt; 2">&#160;</xsl:if><xsl:apply-templates select="."/></li>
              </xsl:if>
            </xsl:for-each>
          </ul>
        </xsl:when>
        <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
        </xsl:choose><xsl:if test="$is-tree">&#160;</xsl:if>&lt;/<xsl:value-of select="name()"/>&gt;</xsl:otherwise>
      </xsl:choose></xe>
  </xsl:template>

  <xsl:template match="/">
    <html>
      <head>
        <title>XML Tree View</title>
        <link rel="stylesheet" type="text/css" href="xml-tree.css"/>
        <script language="JavaScript" type="text/javascript"
                src="js/prototype.js">
        </script>
        <script language="JavaScript" type="text/javascript"
                src="xml-tree.js">
        </script>
      </head>
      <body onload="xmlTreeInit()">
        <xsl:if test="0">
          <div class="DEBUG"><xsl:value-of
          select="system-property('xsl:version')"/></div>
          <div class="DEBUG"><xsl:value-of select="generate-id(.)"/></div>
        </xsl:if>
        <div id="tree">
          <xsl:for-each select="node()">
            <div><xsl:apply-templates select="."/></div>
          </xsl:for-each>
        </div>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
