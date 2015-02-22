package gsearunner;

import java.sql.*;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * 
 * @author Juan José Díaz Montaña
 */
public class DataBase {

    private static String url = "jdbc:mysql://localhost/go";
    private static String user = "root";
    private static String password = "root";
    private static Connection connection = null;

    public static void setConnection(String newUrl, String newUser, String newPassword) {
        url = "jdbc:mysql://" + newUrl;
        user = newUser;
        password = newPassword;
    }

    public static void testConnection() throws SQLException, InstantiationException, IllegalAccessException, ClassNotFoundException {
        if (connection == null || connection.isClosed()) {
            Class.forName("com.mysql.jdbc.Driver").newInstance();
            connection = DriverManager.getConnection(url, user, password);
            closeConnection();
        }
    }

    /**
     * The database connection is implemented using a singleton.
     * This way, there can be one connection at the most
     */
    public static void openConnection()
    {
        try
        {
            if (connection == null || connection.isClosed())
            {
                Class.forName("com.mysql.jdbc.Driver").newInstance();
                connection = DriverManager.getConnection(url, user, password);
            }
            else {
                Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "There is already a connection to a database.");
            }
        } catch (SQLException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Can''t connect to the database.\n{0}", e.getMessage());
        } catch (ClassNotFoundException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Can''t find a MySQL JDBC driver.\n{0}", e.getMessage());
        } catch (InstantiationException | IllegalAccessException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Error opening the connection: \n{0}", e.getMessage());
        }
    }

    public static void closeConnection() {
        try {
            if (connection != null && !connection.isClosed()) {
                connection.close();
                connection = null;
            }
        } catch (SQLException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Error closing the connection.\n{0}", e.getMessage());
        }
    }

   /**
     * Execute the SQL command sent as parameter
     * 
     * @param sql SQL query to be executed
     * @return The resulting ResultSet
     */
    public static ResultSet executeQuery(String sql) {
        ResultSet rs = null;
        try {
            Statement statement = connection.createStatement();
            rs = statement.executeQuery(sql);
        } catch (SQLException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Error in the execution of the SQL query.\nWrong query: \n{0}\n{1}", new Object[]{sql, e.getMessage()});
        }
        return rs;
    }
    
    /**
     * Execute the SQL command sent as parameter
     * 
     * @param sql SQL query to be executed
     * @return The resulting ResultSet
     */
    public static ResultSet execute(String sql) {
        ResultSet rs = null;
        try {
            Statement statement = connection.createStatement();
            statement.execute(sql);
        } catch (SQLException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Error in the execution of the SQL query.\n" + "Wrong query: \n{0}\n{1}", new Object[]{sql, e.getMessage()});
        }
        return rs;
    }
    
    public static void closeQuery(ResultSet rs) {
        try {
            Statement stm = rs.getStatement();
            rs.close();
            stm.close();
        } catch (SQLException e) {
            Logger.getLogger(GSEARunner.class.getName()).log(Level.SEVERE, "Error cleaning the resources for query." + "\n{0}", e.getMessage());
        }
    }
}