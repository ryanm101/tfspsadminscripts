<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:template match="Releasenotes">
  <html>
   <head>
    <Title><xsl:value-of select="Title"/></Title>
   </head>
   <body>
    <center>
     <h1>Release Notes for <xsl:value-of select="Title"/></h1>
     <h4>Created by <xsl:value-of select="Createdby"/> on <xsl:value-of select="Createdon"/></h4>
    </center>
    <xsl:for-each select="Projects/Project">
     <h2>Project: <xsl:value-of select="Name"/></h2>
     <xsl:for-each select="Definitions/Definition">
      <h3>Build Definition: <xsl:value-of select="Name"/></h3>
      <center>
       <xsl:for-each select="Builds/Build"> 
        <table border="1">
         <tr>
          <th>Number</th>
          <th>Quality</th>
          <th>Start Time</th>
          <th>End Time</th>
          <th>Runtime (Min)</th>
          <th>Reason</th>
          <th>Build Log</th>
          <th>Drop Location</th>
         </tr>
         <tr>
          <td><xsl:value-of select="Number"/></td>
          <td><xsl:value-of select="Quality"/></td>
          <td><xsl:value-of select="Starttime"/></td>
          <td><xsl:value-of select="Endtime"/></td>
          <td width="70pixels" align="center"><xsl:value-of select="Runtime"/></td>
          <td><xsl:value-of select="Reason"/></td>
          <td><a><xsl:attribute name="href"><xsl:value-of select="Log"/></xsl:attribute>Build Log</a></td>
          <td><a><xsl:attribute name="href"><xsl:value-of select="Drop"/></xsl:attribute>Build Drop</a></td>
         </tr>
        </table>
        <table border="1">
         <tr>
          <th>Source Version</th>
          <th>Requested by</th>
          <th>Requested for</th>
          <th>Reason</th>
         </tr>
         <tr>
          <td><xsl:value-of select="Sourceversion"/></td>
          <td><xsl:value-of select="Requestedby"/></td>
          <td><xsl:value-of select="Requestedfor"/></td>
          <td><xsl:value-of select="Reason"/></td>
         </tr>
        </table>
        <h3>Configurations</h3>
        <xsl:for-each select="Configurations/Configuration"> 
        <table border="1">
         <tr>
          <th>Flavour</th>
          <th>Platform</th>
          <th>Total Compilation Warnings</th>
          <th>Total Compilation Errors</th>
         </tr>
         <tr>
          <td><xsl:value-of select="Flavour"/></td>
          <td><xsl:value-of select="Platform"/></td>
          <td><xsl:value-of select="CompilationWarnings"/></td>
          <td><xsl:value-of select="CompilationErrors"/></td>
         </tr>
        </table>
        </xsl:for-each>
         <h3>WorkItems</h3>
         <table border="1">
          <tr>
           <th>ID</th>
           <th>Title</th>
           <th>Created By</th>
          </tr>
          <xsl:for-each select="Workitems/Workitem"> 
          <tr>
           <td width="50pixels"><a><xsl:attribute name="href"><xsl:value-of select="Url"/></xsl:attribute><xsl:value-of select="ID"/></a></td>
           <td width="600pixels"><xsl:value-of select="Title"/></td>
           <td width="150pixels"><xsl:value-of select="Createdby"/></td>
          </tr>
          </xsl:for-each>
         </table>
         <h3>Unassociated Changes</h3>
         <table border="1">
          <tr>
           <th>ID</th>
           <th>Committed By</th>
           <th>Committed On</th>
           <th>Comment</th>
          </tr>
          <xsl:for-each select="UnassignedChangesets/Changeset"> 
          <tr>
           <td width="50pixels"><a><xsl:attribute name="href"><xsl:value-of select="Url"/></xsl:attribute><xsl:value-of select="ID"/></a></td>
           <td width="150pixels"><xsl:value-of select="Committedby"/></td>
           <td width="140pixels"><xsl:value-of select="Committedon"/></td>
           <td width="460pixels"><xsl:value-of select="Comment"/></td>
          </tr>
          </xsl:for-each>
         </table>
         <hr  />
       </xsl:for-each>  
      </center>
     </xsl:for-each>
    </xsl:for-each>
   </body>
  </html>
 </xsl:template> 
</xsl:stylesheet>