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
        // Folder variables
        URI GSEA_FOLDER;
        try {
            GSEA_FOLDER = new URI (System.getProperty("user.dir"))
                    .relativize(new URI(GSEARunner.class.getProtectionDomain()
                            .getCodeSource().getLocation().getPath()))
                    .resolve("./");
        } catch (URISyntaxException ex) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, null, ex);
            System.exit(-1);
            return;
        }
        String STUDY_LABEL = "EvoTol_Analysis";
	String INPUT_FOLDER = GSEA_FOLDER.resolve("Inputs").toString();
	String RESULTS_FOLDER = GSEA_FOLDER.resolve("Results").toString();
	String DATA_FOLDER = GSEA_FOLDER.resolve("Data").toString();
        String LOG_FILE = GSEA_FOLDER.resolve("../../log/gsea.log").toString();
        
        // Logger configuration
        Logger logger = Logger.getLogger(GSEARunner.class.getName());   
        try {  
            FileHandler fh = new FileHandler(LOG_FILE);  
            logger.addHandler(fh);
            SimpleFormatter formatter = new SimpleFormatter();  
            fh.setFormatter(formatter);  
            logger.info("GSEA Runner Started");
        } catch (SecurityException | IOException ex) {  
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, null, ex);
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
                input = new FileInputStream(GSEA_FOLDER + "/config.properties");

                prop.load(input);

                DATABASE = prop.getProperty("database");
                USER = prop.getProperty("dbuser");
                PASSWORD = prop.getProperty("dbpassword");
                SLEEPTIME = Integer.parseInt(prop.getProperty("sleeptime"));

            } catch (IOException ex) {
                Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Can't read the properties file.", ex);
                System.exit(-1);
            } finally {
                if (input != null) {
                    try {
                        input.close();
                    } catch (IOException e) {
                        Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Can't close the properties file.", e);
                        System.exit(-1);
                    }
                }
            }

            DataBase.setConnection(DATABASE, USER, PASSWORD);
            try {
                DataBase.testConnection();
            } catch (SQLException | InstantiationException | IllegalAccessException | ClassNotFoundException ex) {
                logger.info("GSEA runner: Can't connect to the database.");
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
                    logger.log(Level.SEVERE, null, ex);
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
                                ranking = DATA_FOLDER + "/" + score + "/" + threshold + "/" + ontology + ".rnk";
                                break;
                            case "RVIS":
                                ranking = DATA_FOLDER + "/" + score + "/" + threshold + ".rnk";
                                break;
                            case "Constraint":
                                ranking = DATA_FOLDER + "/" + score + "/" + threshold + ".rnk";
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
                        logger.log(Level.INFO, "GSEA runner: Analysis with ID = {0} failed", id);
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