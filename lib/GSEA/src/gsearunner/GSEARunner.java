package gsearunner;

import edu.mit.broad.genome.Constants;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;
import java.util.concurrent.TimeUnit;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;
import xtools.gsea.GseaPreranked;

/**
 *
 * @author Juan Jose Díaz
 */
public class GSEARunner {
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) {
        Logger logger = Logger.getLogger(GSEARunner.class.getName());  
        // Folder variables
        URI WGPA_FOLDER;
        URI GSEA_FOLDER;
        URI GSEA_DATA_FOLDER;
        try {
            GSEA_FOLDER = new URI (System.getProperty("user.dir"))
                    .relativize(new URI(GSEARunner.class.getProtectionDomain()
                    .getCodeSource().getLocation().getPath()));
            WGPA_FOLDER = GSEA_FOLDER.resolve("../../");
            GSEA_DATA_FOLDER = WGPA_FOLDER.resolve("data/GSEA/");
        } catch (URISyntaxException ex) {
            logger.log(Level.SEVERE, "Can't resolve local path", ex);
            System.exit(-1);
            return;
        }
        String STUDY_LABEL = "WGPA_Analysis";
    String INPUT_FOLDER = GSEA_DATA_FOLDER.resolve("Inputs/").toString();
    String RANKINGS_FOLDER = GSEA_DATA_FOLDER.resolve("Rankings/").toString();
    String RESULTS_FOLDER = GSEA_DATA_FOLDER.resolve("Results/").toString();
        
        // Logger configuration 
        try {  
            FileHandler fh = new FileHandler(WGPA_FOLDER.resolve("log/gsea.log").toString());  
            logger.addHandler(fh);
            SimpleFormatter formatter = new SimpleFormatter();  
            fh.setFormatter(formatter);  
            logger.info("GSEA Runner Started");
        } catch (SecurityException | IOException ex) {  
           logger.log(Level.SEVERE, "Can't start logger", ex);
            System.exit(-1);
        }  
        
        try {
            // Database connection
            Properties prop = new Properties();
            InputStream input = null;

            String DATABASE = null;
            String USER = null;
            String PASSWORD = null;
            int SLEEPTIME = 0;
            try {
                input = new FileInputStream(GSEA_FOLDER.resolve("config.properties").toString());

                prop.load(input);

                DATABASE = prop.getProperty("database");
                USER = prop.getProperty("dbuser");
                PASSWORD = prop.getProperty("dbpassword");
                SLEEPTIME = Integer.parseInt(prop.getProperty("sleeptime"));

            } catch (IOException ex) {
                logger.log(Level.SEVERE, "Can't read the properties file.", ex);
                System.exit(-1);
            } finally {
                if (input != null) {
                    try {
                        input.close();
                    } catch (IOException e) {
                        logger.log(Level.SEVERE, "Can't close the properties file.", e);
                        System.exit(-1);
                    }
                }
            }

            DataBase.setConnection(DATABASE, USER, PASSWORD);
            try {
                DataBase.testConnection();
            } catch (SQLException | InstantiationException | IllegalAccessException | ClassNotFoundException ex) {
                logger.log(Level.SEVERE, "Can't connect to the database.", ex);
                System.exit(-1);
            }

            System.setProperty(Constants.MAKE_REPORT_DIR_KEY, "false");

            while (true) {
                int id = -1;
                String score = null;
                String ontology = null;
                String threshold = null;
                String extension = null;

                DataBase.openConnection();
                ResultSet rs = DataBase.executeQuery("SELECT id, score, ontology, threshold, input"
                        + " FROM GSEAAnalysis WHERE status = \"Queued\" LIMIT 1;");
                try {
                    if (rs.next()) {
                        id = rs.getInt("id");
                        score = rs.getString("score");
                        ontology = rs.getString("ontology");
                        threshold = rs.getString("threshold");
                        extension = rs.getString("input");
                    }
                } catch (SQLException ex) {
                    logger.log(Level.SEVERE, "SQL Exception getting next analysis from queue.", ex);
                }

                //try Getting from db
                if (id > -1) {
                    logger.log(Level.INFO, "GSEA runner: Starting analysis with ID = {0}", id);
                    DataBase.execute("UPDATE GSEAAnalysis "
                        + "SET status = \"Running\" WHERE id = " + id + ";");
                    try {
                        String ranking;
                        switch (score != null ? score : "") {
                            case "EvoTol":
                                ranking = RANKINGS_FOLDER + "/" + score + "/" + threshold + "/" + ontology + ".rnk";
                                break;
                            case "RVIS":
                                ranking = RANKINGS_FOLDER + "/" + score + "/" + threshold + ".rnk";
                                break;
                            case "Constraint":
                                ranking = RANKINGS_FOLDER + "/" + score + "/" + threshold + ".rnk";
                                break;
                            case "Custom":
                                ranking = INPUT_FOLDER + "/" + id + ".rnk";
                                break;
                            default:
                                throw new IllegalArgumentException("The score selected (" + score + ")is not supported.");
                        }

                        String params = " -gmx " + INPUT_FOLDER + "/" + id + "." + extension
                            + " -rnk " + ranking.replace(' ', '_').replace('*', '/')
                            + " -rpt_label " + STUDY_LABEL
                            + " -out " + RESULTS_FOLDER + "/" + id
                            + " -collapse false" // Don't use a chip file and randomize gene sets.
                            + " -norm meandiv -nperm 1000 -scoring_scheme weighted"
                            + " -make_sets true -plot_top_x 50 -rnd_seed timestamp"
                            + " -set_max 500 -set_min 15 -zip_report false -gui false";
                        GseaPreranked tool = new GseaPreranked(params.split("\\s+"));
                        tool.execute();
                        //Add the success to the db
                        DataBase.execute("UPDATE GSEAAnalysis "
                            + "SET status = \"Completed\" WHERE id = " + id + ";");
                        logger.log(Level.INFO, "GSEA runner: Analysis with ID = {0} completed", id);
                    } catch (Throwable t) {
                        // if the rpt dir was made try to rename it so that easily identifiable
                        DataBase.execute("UPDATE GSEAAnalysis "
                            + "SET status = \"Error\", error = \"" + t.getMessage()+ "\" "
                            + "WHERE id = " + id + ";");
                        logger.log(Level.INFO, "GSEA runner: Analysis with ID = " +  id + " failed", t);
                    }
                    finally {
                        DataBase.closeConnection();
                    }
                }
                else {
                    DataBase.closeConnection();
                    try {
                        logger.log(Level.INFO, "GSEA runner: No analysis queued. Sleep.");
                        TimeUnit.MINUTES.sleep(SLEEPTIME);
                    } catch (InterruptedException ex) {
                        logger.log(Level.SEVERE, null, ex);
                    }
                }
            }
        } catch (Exception e) {
            logger.log(Level.SEVERE, "Is dead!", e);
        }
    }
}